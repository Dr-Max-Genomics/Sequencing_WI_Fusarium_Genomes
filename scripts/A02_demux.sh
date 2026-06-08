#!/bin/bash -l
#SBATCH --job-name=Dor_Demux
#SBATCH -A silage_microbiome
#SBATCH -p atlas
#SBATCH --qos=normal
#SBATCH -N 1
#SBATCH -n 40
#SBATCH --mem=120G
#SBATCH -t 8:00:00
#SBATCH --mail-user=maxwell.chibuogwu@usda.gov
#SBATCH --mail-type=BEGIN,END,FAIL

set -euo pipefail

# =======================================================================
# A02_demux.sh   —   ATLAS CPU step (A-series)
# -----------------------------------------------------------------------
# Purpose : Split the basecalled BAM (calls.bam from A01) into per-barcode
#           BAMs using dorado demux.
# Cluster : ATLAS (CPU partition — no GPU needed for demux).
# -----------------------------------------------------------------------
# IMPORTANT — demux stringency choice (batch_2026-May / MinKNOW path):
#   This batch's assembly came from MinKNOW-derived FASTQs (single-ended
#   barcoding by default). To keep the assembly read population and the
#   polishing read population drawn from the same criterion, A02 here
#   uses SINGLE-ENDED demux (no --barcode-both-ends). If A02 were
#   stricter than MinKNOW, the polishing step (A05) would use a strict
#   subset of reads against an assembly built from a more permissive set
#   — a methodological mismatch.
#
#   For batches where the entire pipeline runs on Atlas (basecall →
#   demux → correct → assemble → polish), --barcode-both-ends IS
#   appropriate (prior batches 1 and 2 used it consistently).
#
#   The flag to add back if needed: --barcode-both-ends
# -----------------------------------------------------------------------
# A-series pipeline context:
#   A01_basecall   →   POD5 → calls.bam + summary.tsv
#   A02_demux      →   calls.bam → per-barcode BAMs    (THIS SCRIPT)
#   A03_bam2fastq  →   per-barcode BAMs → per-barcode fastq.gz (next)
#         ↓  transfer to Ceres for preprocessing (02→05)
# -----------------------------------------------------------------------
# Usage : sbatch A02_demux.sh
#         (single non-array job; dorado demux handles parallelism via --threads)
# Input : ${A01_OUT_DIR}/calls.bam   (must have move tables 'mv' tag)
# Output: ${OUT_DIR}/{barcode01..96}.bam + barcoding_summary.txt
# Notes :
#   - --kit-name SQK-NBD114-96: matches batch 1/2 library prep.
#   - NO --barcode-both-ends: single-ended demux to match MinKNOW's default.
#     See header for rationale. Add back for Atlas-only pipelines.
#   - --emit-summary: writes barcoding_summary.txt with per-read assignment.
#   - --no-classify is NOT used: we let dorado classify barcodes here
#     since A01 was run WITHOUT --kit-name (cleaner separation of concerns).
# =======================================================================

# -----------------------------------------------------------------------
# HARDCODED Atlas paths  (EDIT PER BATCH)
# -----------------------------------------------------------------------
ATLAS_BATCH_DIR="/90daydata/silage_microbiome/Max_Fus_Batch3"
A01_OUT_DIR="${ATLAS_BATCH_DIR}/A01_basecall"
INPUT_BAM="${A01_OUT_DIR}/calls.bam"
OUT_DIR="${ATLAS_BATCH_DIR}/A02_demux"
SUMMARY_FILE="${OUT_DIR}/barcoding_summary.txt"
LOG_DIR_BASE="${ATLAS_BATCH_DIR}/logs"
LOG_DIR="${LOG_DIR_BASE}/demux"

# -----------------------------------------------------------------------
# Demux parameters  (match batch 1/2 methodology)
# -----------------------------------------------------------------------
KIT_NAME="SQK-NBD114-96"

# -----------------------------------------------------------------------
# Set up logging — match A01/A04 pattern: ${ATLAS_BATCH_DIR}/logs/<step>/
# Captures stdout AND stderr into one timestamped file per job.
# -----------------------------------------------------------------------
mkdir -p "${OUT_DIR}" "${LOG_DIR}"
log_file="${LOG_DIR}/A02_demux_${SLURM_JOB_ID}.log"
exec >"${log_file}" 2>&1

echo "=========================================="
echo "[$(date)] dorado demux — ATLAS CPU"
echo "Input BAM:    ${INPUT_BAM}"
echo "Output dir:   ${OUT_DIR}"
echo "Kit:          ${KIT_NAME}"
echo "Stringency:   single-ended (matches MinKNOW default for batch 3)"
echo "Job:          ${SLURM_JOB_ID}"
echo "Host:         $(hostname)"
echo "Threads:      ${SLURM_NTASKS:-1}"
echo "=========================================="

# Validate input
if [[ ! -s "${INPUT_BAM}" ]]; then
    echo "ERROR: input BAM not found or empty: ${INPUT_BAM}" >&2
    echo "Did A01_basecall.sh complete successfully?" >&2
    exit 1
fi

# Resolve symlink for the size report (calls.bam in A01 may be a symlink)
real_bam=$(readlink -f "${INPUT_BAM}")
echo "Input BAM resolved: ${real_bam}"
echo "Input BAM size:     $(du -sh "${real_bam}" | cut -f1)"

# Skip if already done — check for any per-barcode BAM in the output dir.
# Compare against existing barcoded files matching the kit pattern.
existing=$(find "${OUT_DIR}" -maxdepth 1 -name "*barcode*.bam" -type f | wc -l)
if [[ "${existing}" -gt 0 ]]; then
    echo "Found ${existing} existing per-barcode BAM(s) in ${OUT_DIR} — skipping demux."
    echo "(Delete the directory contents to re-demux.)"
    exit 0
fi

# -----------------------------------------------------------------------
# Run dorado demux
# -----------------------------------------------------------------------
module purge
module load dorado

echo "[$(date)] Starting demux..."

dorado demux \
    --kit-name "${KIT_NAME}" \
    --emit-summary \
    --threads "${SLURM_NTASKS:-1}" \
    --output-dir "${OUT_DIR}" \
    "${INPUT_BAM}"

echo "[$(date)] Demux complete."

# -----------------------------------------------------------------------
# Verify outputs and report per-barcode yields
# -----------------------------------------------------------------------
module load samtools

echo
echo "--- Per-barcode BAM inventory ---"
shopt -s nullglob
barcoded_bams=( "${OUT_DIR}"/*barcode*.bam )
shopt -u nullglob

if [[ ${#barcoded_bams[@]} -eq 0 ]]; then
    echo "WARN: no per-barcode BAMs produced — check ${SUMMARY_FILE} for diagnostics" >&2
    ls -la "${OUT_DIR}" >&2
    exit 1
fi

echo "Barcode BAMs produced: ${#barcoded_bams[@]}"
printf "%-40s %12s %14s\n" "FILE" "SIZE" "READS"
for bam in "${barcoded_bams[@]}"; do
    sz=$(du -sh "${bam}" | cut -f1)
    rc=$(samtools view -c "${bam}" 2>/dev/null || echo "?")
    printf "%-40s %12s %14s\n" "$(basename "${bam}")" "${sz}" "${rc}"
done

# Report unclassified reads if present
unclassified=$(find "${OUT_DIR}" -maxdepth 1 -name "*unclassified*.bam" -type f | head -1)
if [[ -n "${unclassified}" ]]; then
    uc_count=$(samtools view -c "${unclassified}" 2>/dev/null || echo "?")
    echo
    echo "Unclassified reads: ${uc_count}  ($(basename "${unclassified}"))"
fi

# Confirm 'mv' tag preserved (matters for downstream A05 polish)
echo
echo "--- Move-table preservation check (first barcode BAM) ---"
sample_bam="${barcoded_bams[0]}"
mv_count=$(samtools view --keep-tag "mv" -c "${sample_bam}" 2>/dev/null || echo "0")
total=$(samtools view -c "${sample_bam}" 2>/dev/null || echo "0")
echo "${sample_bam##*/}: reads with 'mv' tag: ${mv_count} / ${total}"
if [[ "${mv_count}" != "${total}" && "${total}" != "0" ]]; then
    echo "WARN: not all reads carry 'mv' tag — A05 polish will use the non-move-aware model" >&2
fi

if [[ -s "${SUMMARY_FILE}" ]]; then
    echo
    echo "Barcoding summary: ${SUMMARY_FILE}"
    echo "(See $(basename "${SUMMARY_FILE}") for per-read barcode assignments.)"
fi

module purge

echo
echo "[$(date)] Done."
echo
echo "NEXT: run A03_bam2fastq.sh to extract per-barcode fastq.gz for transfer to Ceres."
