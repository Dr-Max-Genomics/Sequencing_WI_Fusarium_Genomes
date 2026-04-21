#!/usr/bin/env bash
set -euo pipefail

#SBATCH -A silage_microbiome
#SBATCH -N 1
#SBATCH -n 32
#SBATCH --mem=150G
#SBATCH -p ceres
#SBATCH -t 6:00:00
#SBATCH --job-name="iprscan"
#SBATCH -o slurm_logs/iprscan_%j.out

# -------------------------------
# Setup
# -------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
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
export AUGUSTUS_CONFIG_PATH="${AUGUSTUS_CONFIG_PATH}"

# Basic DB readiness check (conservative)
if [[ ! -d "${APPTAINERENV_FUNANNOTATE_DB}/uniprot" ]] || [[ ! -d "${APPTAINERENV_FUNANNOTATE_DB}/pfam" ]]; then
  echo "ERROR: Funannotate DB at ${APPTAINERENV_FUNANNOTATE_DB} looks incomplete." >&2
  echo "       Please run 'funannotate setup' once (outside the array) and retry." >&2
  exit 1
fi

module load funannotate

predict_dir="${FUN_PREDICT_DIR}/${sample}"

if [[ ! -d "${predict_dir}" ]]; then
  echo "ERROR: Predict directory not found: ${predict_dir}" >&2
  exit 1
fi

echo "Predict input: ${predict_dir}"
echo "Output dir:    ${outdir}"
echo "IPR XML:       ${ipr_xml}"

funannotate annotate \
  -i "${predict_dir}" \
  -o "${outdir}" \
  --iprscan "${ipr_xml}"

echo "[$(date)] Finished funannotate annotate for sample: ${sample}"
