#!/usr/bin/env bash
#SBATCH -A silage_microbiome
#SBATCH -N 1
#SBATCH -n 70
#SBATCH --mem=300G
#SBATCH -p ceres
#SBATCH -t 1-0
#SBATCH --job-name=porechop
#SBATCH --array=1-7
#SBATCH --output=/dev/null

set -euo pipefail

# -----------------------------------------------------------------------
# 02_porechop.sh
# Purpose : Remove Oxford Nanopore adapter sequences (Porechop).
#           Runs BEFORE dedup in the canonical S1 order:
#           concat -> porechop -> dedup -> nanofilt -> nanoplot
# Usage   : sbatch --array=1 scripts/02_porechop.sh     # test one
#           sbatch --array=2-7 scripts/02_porechop.sh   # rest of batch
# Input   : 00_Raw_Data/{barcode}/{barcode}.fastq.gz  (from 01_concat)
# Output  : 02_Trimming/PC_{sample_id}.fastq
# Module  : porechop is a standalone module. It conflicts with miniconda,
#           so this script does NOT load/activate conda. Keep them separate.
# -----------------------------------------------------------------------

PROJECT_ROOT="${PROJECT_ROOT:-/project/silage_microbiome/max.chi/fusarium_sequencing}"
source "${PROJECT_ROOT}/config/paths.sh"

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

# -----------------------------------------------------------------------
# Paths
# -----------------------------------------------------------------------
INPUT="${RAW_DIR}/${barcode}/${barcode}.fastq.gz"
OUTPUT="${TRIM_DIR}/PC_${sample_id}.fastq"

mkdir -p "${TRIM_DIR}" "${LOG_DIR}/porechop"
log_file="${LOG_DIR}/porechop/${sample_id}.log"
exec >"${log_file}" 2>&1

echo "=========================================="
echo "[$(date)] Porechop adapter trimming"
echo "Barcode:  ${barcode}"
echo "Sample:   ${sample_id}"
echo "Input:    ${INPUT}"
echo "Output:   ${OUTPUT}"
echo "Manifest: ${MANIFEST}"
echo "Job ID:   ${SLURM_JOB_ID} / task ${SLURM_ARRAY_TASK_ID}"
echo "Host:     $(hostname)"
echo "=========================================="

# Validate input
if [[ ! -s "${INPUT}" ]]; then
    echo "ERROR: input not found or empty: ${INPUT}" >&2
    echo "Did 01_concat.sh run successfully for ${barcode}?" >&2
    exit 1
fi

# Skip if already done
if [[ -s "${OUTPUT}" ]]; then
    echo "Output exists and non-empty — skipping: ${OUTPUT}"
    exit 0
fi

# -----------------------------------------------------------------------
# Load Porechop (standalone module — do NOT load miniconda here)
# -----------------------------------------------------------------------
module load porechop

echo "[$(date)] Running Porechop..."
porechop-runner.py \
    -i "${INPUT}" \
    -o "${OUTPUT}" \
    -t "${SLURM_NTASKS}"

if [[ ! -s "${OUTPUT}" ]]; then
    echo "ERROR: output empty after Porechop: ${OUTPUT}" >&2
    exit 1
fi

echo "[$(date)] Done: ${sample_id} → ${OUTPUT}"
echo "Output size: $(du -sh "${OUTPUT}" | cut -f1)"
