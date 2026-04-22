#!bin/bash
set -euo pipefail

#SBATCH -A silage_microbiome
#SBATCH -N 1
#SBATCH -n 32
#SBATCH --mem=150G
#SBATCH -p ceres
#SBATCH -t 6:00:00
#SBATCH --job-name=FUN_annotate
#SBATCH --array=1-10
#SBATCH --output=/dev/null

# -------------------------------
# Setup
# -------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="/project/silage_microbiome/max.chi/fusarium_sequencing"
source "${PROJECT_ROOT}/config/paths.sh"

mkdir -p "${FUN_ANNOTATE_DIR}" "${LOG_DIR}/annotate"

SAMPLE_LIST="${BATCH_DIR}/sample_list.txt"
if [[ ! -f "${SAMPLE_LIST}" ]]; then
  echo "ERROR: sample_list.txt not found at ${SAMPLE_LIST}. Run InterProScan script first." >&2
  exit 1
fi

if [[ -z "${SLURM_ARRAY_TASK_ID:-}" ]]; then
  echo "SLURM_ARRAY_TASK_ID is not set; run as an array job." >&2
  exit 1
fi

sample=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "${SAMPLE_LIST}" || true)
if [[ -z "${sample}" ]]; then
  echo "No sample found for SLURM_ARRAY_TASK_ID=${SLURM_ARRAY_TASK_ID}" >&2
  exit 0
fi

log_file="${LOG_DIR}/annotate/${sample}.log"
exec >"${log_file}" 2>&1

echo "[$(date)] Starting funannotate annotate for sample: ${sample}"

# Check InterProScan XML
ipr_xml="${INTERPROSCAN_DIR}/${sample}.xml"
if [[ ! -s "${ipr_xml}" ]]; then
  echo "ERROR: InterProScan XML not found or empty: ${ipr_xml}" >&2
  exit 1
fi

# Check AntiSMASH GBK and derive name from sample (e.g., FunAnnotate_Bar36 -> FusBar36.scaffold.gbk)
num="${sample##*Bar}"
anti_gbk="${ANTISMASH_DIR}/FusBar${num}.scaffolds.gbk"
if [[ ! -s "${anti_gbk}" ]]; then
  echo "ERROR: AntiSMASH GBK not found or empty: ${anti_gbk}" >&2
  exit 1
fi

# Output directory for this sample
outdir="${FUN_ANNOTATE_DIR}/${sample}"
# Skip if annotate already produced GFF3
if [[ -d "${outdir}" ]] && compgen -G "${outdir}/annotate_results/*.gff3" > /dev/null; then
  echo "Annotate output appears complete (GFF3 present) in ${outdir} — skipping."
  exit 0
fi

mkdir -p "${outdir}"

# Funannotate DB + Augustus env
export APPTAINERENV_FUNANNOTATE_DB="${FUNANNOTATE_DB_PATH}"
export AUGUSTUS_CONFIG_PATH="${AUGUSTUS_CONFIG_PATH:-/90daydata/silage_microbiome/max_seq/jan_batch2_all_barcodes/11_FunAnnotate/augustus/config}"

module load funannotate

predict_dir="${FUN_PREDICT_DIR}/${sample}"

if [[ ! -d "${predict_dir}" ]]; then
  echo "ERROR: Predict directory not found: ${predict_dir}" >&2
  exit 1
fi

echo "[$(date)] Running funannotate annotate"
echo "Predict input: ${predict_dir}"
echo "Output dir:    ${outdir}"
echo "IPR XML:       ${ipr_xml}"
echo "AntiSMASH:     ${anti_gbk}"

funannotate annotate \
  -i "${predict_dir}" \
  -o "${outdir}" \
  --iprscan "${ipr_xml}" \
  --antismash "${anti_gbk}" \
  --cpus 32

echo "[$(date)] Finished funannotate annotate for sample: ${sample}"
