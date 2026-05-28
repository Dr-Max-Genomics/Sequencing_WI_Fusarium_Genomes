#!/usr/bin/env bash
#SBATCH -A silage_microbiome
#SBATCH -N 1
#SBATCH -n 32
#SBATCH --mem=150G
#SBATCH -p ceres
#SBATCH -t 6:00:00
#SBATCH --job-name=FUN_annotate
#SBATCH --array=1-9
#SBATCH --output=/dev/null

set -euo pipefail

PROJECT_ROOT="/project/silage_microbiome/max.chi/fusarium_sequencing"
source "${PROJECT_ROOT}/config/paths.sh"

mkdir -p "${LOG_DIR}/annotate"

# -----------------------------------------------------------------------
# Standard manifest read — all 9 columns. See README §7.
# -----------------------------------------------------------------------
LINE_NUM=$((SLURM_ARRAY_TASK_ID + 1))
IFS=$'\t' read -r \
    barcode sample_id assembly_file busco_name earlgrey_species \
    funannotate_name funannotate_species protein_evidence_file antismash_file \
    < <(sed -n "${LINE_NUM}p" "${MANIFEST}")

if [[ -z "${sample_id:-}" ]]; then
    echo "ERROR: no sample at manifest line ${LINE_NUM} of ${MANIFEST}" >&2
    exit 1
fi

# Per-sample log
log_file="${LOG_DIR}/annotate/${sample_id}.log"
exec >"${log_file}" 2>&1

echo "[$(date)] Starting funannotate annotate for sample: ${sample_id}"
echo "Manifest: ${MANIFEST}"

# Check InterProScan XML
ipr_xml="${INTERPROSCAN_DIR}/${sample_id}.xml"
if [[ ! -s "${ipr_xml}" ]]; then
    echo "ERROR: InterProScan XML not found or empty: ${ipr_xml}" >&2
    exit 1
fi

# Check AntiSMASH GBK
anti_gbk="${ANTISMASH_DIR}/${antismash_file}"
if [[ ! -s "${anti_gbk}" ]]; then
    echo "ERROR: AntiSMASH GBK not found or empty: ${anti_gbk}" >&2
    exit 1
fi

# Output directory for this sample
outdir="${FUN_PREDICT_DIR}/${funannotate_name}"

# Skip if annotate already produced GFF3
if [[ -d "${outdir}" ]] && compgen -G "${outdir}/annotate_results/*.gff3" > /dev/null; then
    echo "Annotate output appears complete (GFF3 present) in ${outdir} — skipping."
    exit 0
fi

mkdir -p "${outdir}"

# Funannotate DB + Augustus env
export APPTAINERENV_FUNANNOTATE_DB="${DB_ROOT}/funannotate_db"
export AUGUSTUS_CONFIG_PATH="${DB_ROOT}/augustus_config/config"
export APPTAINER_TMPDIR="$TMPDIR"

module load funannotate

predict_dir="${FUN_PREDICT_DIR}/${funannotate_name}"
if [[ ! -d "${predict_dir}" ]]; then
    echo "ERROR: Predict directory not found: ${predict_dir}" >&2
    exit 1
fi

echo "[$(date)] Running funannotate annotate"
echo "Predict input: ${predict_dir}"
echo "IPR XML:       ${ipr_xml}"
echo "AntiSMASH:     ${anti_gbk}"

funannotate annotate \
    -i "${predict_dir}" \
    --iprscan "${ipr_xml}" \
    --antismash "${anti_gbk}" \
    --cpus 32

echo "[$(date)] Finished funannotate annotate for sample: ${sample_id}"
