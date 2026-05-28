#!/usr/bin/env bash
#SBATCH -A silage_microbiome
#SBATCH -N 1
#SBATCH -n 4
#SBATCH --mem=20G
#SBATCH -p ceres
#SBATCH -t 2:00:00
#SBATCH --job-name=concat
#SBATCH --array=1-7
#SBATCH --output=/dev/null

set -euo pipefail

# -----------------------------------------------------------------------
# 01_concat.sh
# Purpose : Concatenate all per-run fastq.gz files within each barcode
#           directory into a single barcodeXX.fastq.gz file.
#           Designed for MinKNOW-basecalled output where each barcode
#           directory may contain multiple .fastq.gz files.
# Usage   : sbatch --array=1 scripts/01_concat.sh     # test one barcode
#           sbatch --array=2-7 scripts/01_concat.sh   # rest of batch
# Input   : RAW_DIR/{barcode}/  containing *.fastq.gz files
# Output  : RAW_DIR/{barcode}/{barcode}.fastq.gz  (combined)
# Notes   : Skips if combined output already exists and is non-empty.
#           Update --array flag to match number of samples in manifest.
# -----------------------------------------------------------------------

PROJECT_ROOT="/project/silage_microbiome/max.chi/fusarium_sequencing"
source "${PROJECT_ROOT}/config/paths.sh"

# -----------------------------------------------------------------------
# Pick sample from manifest
# -----------------------------------------------------------------------
MANIFEST="${BATCH_DIR}/batch3_manifest.tsv"
LINE_NUM=$((SLURM_ARRAY_TASK_ID + 1))
IFS=$'\t' read -r \
    barcode sample_id assembly_file busco_name earlgrey_species \
    funannotate_name funannotate_species protein_evidence_file antismash_file \
    < <(sed -n "${LINE_NUM}p" "$MANIFEST")

if [[ -z "${barcode:-}" ]]; then
    echo "ERROR: no sample at manifest line ${LINE_NUM} of ${MANIFEST}" >&2
    exit 1
fi

# -----------------------------------------------------------------------
# Paths
# -----------------------------------------------------------------------
BARCODE_DIR="${RAW_DIR}/${barcode}"
OUTPUT_FILE="${BARCODE_DIR}/${barcode}.fastq.gz"

mkdir -p "${LOG_DIR}/concat"

# Per-sample log
log_file="${LOG_DIR}/concat/${sample_id}.log"
exec >"${log_file}" 2>&1

echo "=========================================="
echo "[$(date)] Concatenation"
echo "Barcode:    ${barcode}"
echo "Sample:     ${sample_id}"
echo "Source dir: ${BARCODE_DIR}"
echo "Output:     ${OUTPUT_FILE}"
echo "Job ID:     ${SLURM_JOB_ID} / task ${SLURM_ARRAY_TASK_ID}"
echo "Host:       $(hostname)"
echo "=========================================="

# Validate source directory
if [[ ! -d "${BARCODE_DIR}" ]]; then
    echo "ERROR: barcode directory not found: ${BARCODE_DIR}" >&2
    exit 1
fi

# Count input files
shopt -s nullglob
input_files=( "${BARCODE_DIR}"/*.fastq.gz )
shopt -u nullglob

# Exclude any previously combined output from input list
filtered_files=()
for f in "${input_files[@]}"; do
    [[ "$f" == "$OUTPUT_FILE" ]] && continue
    filtered_files+=("$f")
done

if [[ ${#filtered_files[@]} -eq 0 ]]; then
    echo "ERROR: no .fastq.gz files found in ${BARCODE_DIR}" >&2
    echo "Contents:" >&2
    ls -lh "${BARCODE_DIR}" >&2
    exit 1
fi

echo "Found ${#filtered_files[@]} input file(s):"
for f in "${filtered_files[@]}"; do
    echo "  $(basename "$f")  ($(du -sh "$f" | cut -f1))"
done

# Skip if already done
if [[ -s "${OUTPUT_FILE}" ]]; then
    echo "Output already exists and is non-empty — skipping: ${OUTPUT_FILE}"
    echo "Size: $(du -sh "${OUTPUT_FILE}" | cut -f1)"
    exit 0
fi

# -----------------------------------------------------------------------
# Concatenate
# -----------------------------------------------------------------------
echo "[$(date)] Concatenating..."

cat "${filtered_files[@]}" > "${OUTPUT_FILE}"

# Verify output
if [[ ! -s "${OUTPUT_FILE}" ]]; then
    echo "ERROR: output file is empty after concat: ${OUTPUT_FILE}" >&2
    exit 1
fi

echo "[$(date)] Done."
echo "Output size: $(du -sh "${OUTPUT_FILE}" | cut -f1)"
echo "Output path: ${OUTPUT_FILE}"
