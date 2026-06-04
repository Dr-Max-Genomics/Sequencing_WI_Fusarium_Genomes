#!/usr/bin/env bash
#SBATCH -A silage_microbiome
#SBATCH -N 1
#SBATCH -n 8
#SBATCH --mem=40G
#SBATCH -p ceres
#SBATCH -t 1:00:00
#SBATCH --job-name=busco_eval_unpolished
#SBATCH --array=1-9
#SBATCH --output=/dev/null

set -euo pipefail

PROJECT_ROOT="/project/silage_microbiome/max.chi/fusarium_sequencing"
source "${PROJECT_ROOT}/config/paths.sh"

# -----------------------------------------------------------------------
# Read manifest (same as polished pipeline)
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

# -----------------------------------------------------------------------
# Unpolished assembly path
# -----------------------------------------------------------------------
UNPOLISHED_DIR="/90daydata/silage_microbiome/max_seq/batch3_2026-May/05_Genome_Assembly"
ASSEMBLY="${UNPOLISHED_DIR}/${sample_id}_flye/assembly.fasta"

if [[ ! -s "${ASSEMBLY}" ]]; then
    echo "ERROR: unpolished assembly not found: ${ASSEMBLY}" >&2
    exit 1
fi

# -----------------------------------------------------------------------
# Output naming
# Ignore manifest busco_name — override with sample_id_unpolished
# -----------------------------------------------------------------------
BUSCO_OUT_NAME="${sample_id}_unpolished"

# -----------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------
mkdir -p "${LOG_DIR}/Busco_eval_unpolished"
log_file="${LOG_DIR}/Busco_eval_unpolished/${sample_id}_unpolished.log"
exec >"${log_file}" 2>&1

echo "=========================================="
echo "[$(date)] BUSCO evaluation (UNPOLISHED)"
echo "Sample ID:        ${sample_id}"
echo "Assembly (raw):   ${ASSEMBLY}"
echo "BUSCO output:     ${BUSCO_OUT_NAME}"
echo "Manifest:         ${MANIFEST}"
echo "Job ID:           ${SLURM_JOB_ID}"
echo "Array task:       ${SLURM_ARRAY_TASK_ID}"
echo "Host:             $(hostname)"
echo "=========================================="

# -----------------------------------------------------------------------
# BUSCO lineage
# -----------------------------------------------------------------------
LINEAGE="hypocreales_odb10"
LINEAGE_PATH="${BUSCO_DOWNLOADS}/lineages/${LINEAGE}"

if [[ ! -d "${LINEAGE_PATH}" ]]; then
    echo "ERROR: lineage folder missing: ${LINEAGE_PATH}" >&2
    ls -la "${BUSCO_DOWNLOADS}/lineages/" >&2 || true
    exit 1
fi

mkdir -p "${BUSCO_DIR}"

module load busco5

busco \
    --in "${ASSEMBLY}" \
    --out "${BUSCO_OUT_NAME}" \
    --out_path "${BUSCO_DIR}" \
    --lineage_dataset "${LINEAGE}" \
    --mode genome \
    --cpu 8 \
    --offline \
    --download_path "${BUSCO_DOWNLOADS}"

echo "[$(date)] Finished BUSCO for ${sample_id} (unpolished)"
