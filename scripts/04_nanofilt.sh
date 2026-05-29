#!/usr/bin/env bash
#SBATCH -A silage_microbiome
#SBATCH -N 1
#SBATCH -n 8
#SBATCH --mem=150G
#SBATCH -p ceres
#SBATCH -t 05:00:00
#SBATCH --job-name=nanofilt
#SBATCH --array=1-7
#SBATCH --output=/dev/null

set -euo pipefail

# -----------------------------------------------------------------------
# 04_nanofilt.sh
# Purpose : Filter out reads shorter than MIN_LEN (default 1000 bp) > Q20
#           Canonical S1 order: concat -> porechop -> dedup -> nanofilt -> nanoplot
# Usage   : sbatch --array=1 scripts/04_nanofilt.sh     # test one
#           sbatch --array=2-7 scripts/04_nanofilt.sh   # rest of batch
# Input   : 02_Trimming/PC_{sample_id}_D.fastq   (from 03_seqkit_dedup)
# Output  : 03_Trimmed_Data/{sample_id}.fastq    (final analysis-ready reads)
# Env     : NanoFilt is in the seqenv conda environment.
# -----------------------------------------------------------------------

PROJECT_ROOT="${PROJECT_ROOT:-/project/silage_microbiome/max.chi/fusarium_sequencing}"
source "${PROJECT_ROOT}/config/paths.sh"

# Minimum read length — override by exporting MIN_LEN before submission
MIN_LEN="${MIN_LEN:-1000}"

# -----------------------------------------------------------------------
# Conda activation (NanoFilt lives in seqenv)
# -----------------------------------------------------------------------
module load miniconda
source activate seq_env

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
INPUT="${TRIM_DIR}/PC_${sample_id}_D.fastq"
OUTPUT="${TRIMMED_DIR}/${sample_id}.fastq"

mkdir -p "${TRIMMED_DIR}" "${LOG_DIR}/nanofilt"
log_file="${LOG_DIR}/nanofilt/${sample_id}.log"
exec >"${log_file}" 2>&1

echo "=========================================="
echo "[$(date)] NanoFilt length filtering"
echo "Barcode:   ${barcode}"
echo "Sample:    ${sample_id}"
echo "Min length:${MIN_LEN} bp"
echo "Input:     ${INPUT}"
echo "Output:    ${OUTPUT}"
echo "Manifest:  ${MANIFEST}"
echo "Job ID:    ${SLURM_JOB_ID} / task ${SLURM_ARRAY_TASK_ID}"
echo "Host:      $(hostname)"
echo "=========================================="

# Validate input
if [[ ! -s "${INPUT}" ]]; then
    echo "ERROR: input not found or empty: ${INPUT}" >&2
    echo "Did 03_seqkit_dedup.sh run successfully for ${sample_id}?" >&2
    exit 1
fi

# Skip if already done
if [[ -s "${OUTPUT}" ]]; then
    echo "Output exists and non-empty — skipping: ${OUTPUT}"
    exit 0
fi

# -----------------------------------------------------------------------
# Run NanoFilt
# -----------------------------------------------------------------------
echo "[$(date)] Running NanoFilt (-l ${MIN_LEN})..."
NanoFilt -q 20 -l "${MIN_LEN}" "${INPUT}" > "${OUTPUT}"

if [[ ! -s "${OUTPUT}" ]]; then
    echo "ERROR: output empty after NanoFilt: ${OUTPUT}" >&2
    exit 1
fi

echo "[$(date)] Done: ${sample_id} → ${OUTPUT}"
echo "Output size: $(du -sh "${OUTPUT}" | cut -f1)"
