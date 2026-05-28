#!/usr/bin/env bash
#SBATCH -A silage_microbiome
#SBATCH -N 1
#SBATCH -n 70
#SBATCH --mem=300G
#SBATCH -p ceres
#SBATCH -t 1-0
#SBATCH --job-name=seqkit_dedup
#SBATCH --array=1-7
#SBATCH --output=/dev/null

set -euo pipefail

# -----------------------------------------------------------------------
# 03_seqkit_dedup.sh
# Purpose : Remove duplicate reads (seqkit rmdup) by name.
#           Runs AFTER porechop in the canonical S1 order:
#           concat -> porechop -> dedup -> nanofilt -> nanoplot
# Usage   : sbatch --array=1 scripts/03_seqkit_dedup.sh     # test one
#           sbatch --array=2-7 scripts/03_seqkit_dedup.sh   # rest of batch
# Input   : 02_Trimming/PC_{sample_id}.fastq      (from 02_porechop)
# Output  : 02_Trimming/PC_{sample_id}_D.fastq    (deduplicated)
#           02_Trimming/{sample_id}_derep_list.txt
# Module  : seqkit available both as module and in seqenv. Uses module here
#           to keep it lightweight (no conda needed).
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
INPUT="${TRIM_DIR}/PC_${sample_id}.fastq"
OUTPUT="${TRIM_DIR}/PC_${sample_id}_D.fastq"
DEREP_LIST="${TRIM_DIR}/${sample_id}_derep_list.txt"

mkdir -p "${TRIM_DIR}" "${LOG_DIR}/seqkit_dedup"
log_file="${LOG_DIR}/seqkit_dedup/${sample_id}.log"
exec >"${log_file}" 2>&1

echo "=========================================="
echo "[$(date)] seqkit rmdup deduplication"
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
    echo "Did 02_porechop.sh run successfully for ${sample_id}?" >&2
    exit 1
fi

# Skip if already done
if [[ -s "${OUTPUT}" ]]; then
    echo "Output exists and non-empty — skipping: ${OUTPUT}"
    exit 0
fi

# -----------------------------------------------------------------------
# Load seqkit (module)
# -----------------------------------------------------------------------
module load seqkit

echo "[$(date)] Running seqkit rmdup..."
seqkit rmdup "${INPUT}" \
    -n \
    -o "${OUTPUT}" \
    -D "${DEREP_LIST}"

if [[ ! -s "${OUTPUT}" ]]; then
    echo "ERROR: output empty after rmdup: ${OUTPUT}" >&2
    exit 1
fi

# Report duplicate findings
if [[ -s "${DEREP_LIST}" ]]; then
    echo "Duplicates found — see ${DEREP_LIST}"
    echo "Duplicate records: $(wc -l < "${DEREP_LIST}")"
else
    echo "No duplicated records."
fi

echo "[$(date)] Done: ${sample_id} → ${OUTPUT}"
echo "Output size: $(du -sh "${OUTPUT}" | cut -f1)"
