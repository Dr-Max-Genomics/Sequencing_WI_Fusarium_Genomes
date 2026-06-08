#!/bin/bash -l
#SBATCH --job-name=Dor_Bam2Fq
#SBATCH -A silage_microbiome
#SBATCH -p atlas
#SBATCH --qos=normal
#SBATCH -N 1
#SBATCH -n 16
#SBATCH -t 4:00:00
#SBATCH --array=1-7
#SBATCH --mail-user=maxwell.chibuogwu@usda.gov
#SBATCH --mail-type=BEGIN,END,FAIL

set -euo pipefail
shopt -s nullglob

# =======================================================================
# A03_bam2fastq.sh   —   ATLAS CPU step (A-series)   [v2]
# -----------------------------------------------------------------------
# Purpose : Convert per-barcode BAMs (from A02_demux) to gzipped FASTQ
#           files, one isolate per array task. Plain FASTQ headers
#           (no HTS tags) — output is meant for FASTQ-consuming tools
#           and direct size comparison against MinKNOW FASTQs.
# Cluster : ATLAS CPU. No GPU needed — samtools fastq is pure CPU work
#           dominated by BAM decompression and gzip compression.
# -----------------------------------------------------------------------
# A03 serves two roles, depending on the batch:
#
#   (a) DIAGNOSTIC (Batch 3): assemblies for this batch were built from
#       MinKNOW-derived FASTQs, not from A02 outputs. A03 here is run
#       as a one-off so the per-barcode FASTQs can be compared against
#       MinKNOW's FASTQs (size, read count, quality distribution).
#       Nothing downstream consumes A03 output for this batch.
#
#   (b) PIPELINE (future batches without MinKNOW-side basecalling):
#       A03 is the SINGULAR source of per-barcode FASTQs for Ceres
#       preprocessing. The output feeds 02_porechop → 03_dedup →
#       04_nanofilt → 05_nanoplot.
#
# The script behaves identically in both modes — the difference is only
# what (if anything) consumes the output downstream.
# -----------------------------------------------------------------------
# A-series pipeline context:
#   A01 basecall  → calls.bam (mv tag; canonical signal source)
#   A02 demux     → per-barcode BAMs (mv tag preserved)
#   A03 bam2fastq → per-barcode fastq.gz  (THIS SCRIPT)
#         ↓  (only in mode (b)) transfer to Ceres 00_Raw_Data/{barcode}/
#   Ceres: SKIP 01_concat (already 1 file per barcode);
#          run 02_porechop → 03_dedup → 04_nanofilt → 05_nanoplot
#         ↓  transfer filtered reads back to Atlas
#   A04 correct   → corrected FASTA (HERRO)
#         ↓  transfer to Ceres
#   Ceres: 06_flye_assemble (--nano-corr) → 07_busco
#         ↓  transfer assembly to Atlas
#   A05 align+polish → per-barcode BAM (from A02) + assembly → polished
# -----------------------------------------------------------------------
# Why plain FASTQ headers (no `-T '*'`):
#   v1 of this script preserved all BAM tags in the FASTQ header via
#   `samtools fastq -T '*'`, aiming to keep the FASTQ "polish-compatible."
#   In practice that goal doesn't apply: A05 polish reads BAM directly
#   from A02, never FASTQ. Meanwhile, the bloated headers (a) make
#   size comparison against MinKNOW FASTQs unfair (extra bytes per
#   record from RG/mv/qs tags), and (b) can confuse downstream FASTQ
#   tools that don't expect HTS-style header fields. Plain FASTQ wins.
#
#   To re-enable tag preservation if ever needed: add `-T '*'` to the
#   `samtools fastq` invocation below.
# -----------------------------------------------------------------------
# Usage :
#   sbatch --array=1 A03_bam2fastq.sh         # test one isolate
#   sbatch --array=1-7 A03_bam2fastq.sh       # full batch (safe to launch all)
# Output: ${OUT_DIR}/{barcode}/{barcode}.fastq.gz
#         (One per-barcode subdir; filename uses the barcode label,
#         not sample_id, to match the Ceres 02_porechop manifest
#         convention.)
# =======================================================================

# -----------------------------------------------------------------------
# HARDCODED Atlas paths and barcode->sample mapping  (EDIT PER BATCH)
# -----------------------------------------------------------------------
ATLAS_BATCH_DIR="/90daydata/silage_microbiome/Max_Batch3"
DEMUX_DIR="${ATLAS_BATCH_DIR}/A02_demux"
OUT_DIR="${ATLAS_BATCH_DIR}/A03_fastq"

# Inline barcode → sample_id mapping (matches batch_2026-May manifest).
# Index by array task ID. barcode03 absent — not sequenced this batch.
# Array indices repack contiguously when barcodes are absent → task 3
# = barcode04, +1 offset thereafter. Matches A05's BARCODE_OF mapping.
declare -A BARCODE_OF SAMPLE_OF
BARCODE_OF[1]="barcode01" ; SAMPLE_OF[1]="Fus_Bar01"   # F. verticillioides
BARCODE_OF[2]="barcode02" ; SAMPLE_OF[2]="Fus_Bar02"   # F. proliferatum
BARCODE_OF[3]="barcode04" ; SAMPLE_OF[3]="Fus_Bar04"   # F. graminearum
BARCODE_OF[4]="barcode05" ; SAMPLE_OF[4]="Fus_Bar05"   # F. annulatum
BARCODE_OF[5]="barcode06" ; SAMPLE_OF[5]="Fus_Bar06"   # F. graminearum
BARCODE_OF[6]="barcode07" ; SAMPLE_OF[6]="Fus_Bar07"   # F. graminearum
BARCODE_OF[7]="barcode08" ; SAMPLE_OF[7]="Fus_Bar08"   # F. sporotrichioides

# -----------------------------------------------------------------------
# Resolve this task's barcode + sample
# -----------------------------------------------------------------------
TASK="${SLURM_ARRAY_TASK_ID}"
barcode="${BARCODE_OF[${TASK}]:-}"
sample_id="${SAMPLE_OF[${TASK}]:-}"

if [[ -z "${barcode}" || -z "${sample_id}" ]]; then
    echo "ERROR: no mapping for array task ${TASK}" >&2
    echo "Edit BARCODE_OF / SAMPLE_OF arrays and --array range." >&2
    exit 1
fi

# -----------------------------------------------------------------------
# Locate input BAM. Dorado demux filename pattern is
# "<RG-hash>_SQK-NBD114-96_barcodeXX.bam". Glob permissively on the
# barcode suffix and require a unique match.
# -----------------------------------------------------------------------
candidates=( "${DEMUX_DIR}"/*"_${barcode}.bam" )

if [[ ${#candidates[@]} -eq 0 ]]; then
    echo "ERROR: no demux BAM found for ${barcode} in ${DEMUX_DIR}" >&2
    echo "Expected a file matching: *_${barcode}.bam" >&2
    ls "${DEMUX_DIR}" >&2 || true
    exit 1
elif [[ ${#candidates[@]} -gt 1 ]]; then
    echo "ERROR: multiple BAMs match ${barcode}:" >&2
    printf '  %s\n' "${candidates[@]}" >&2
    exit 1
fi
INPUT_BAM="${candidates[0]}"

OUT_BARCODE_DIR="${OUT_DIR}/${barcode}"
OUTPUT_FASTQ_GZ="${OUT_BARCODE_DIR}/${barcode}.fastq.gz"

# -----------------------------------------------------------------------
# Set up logging — match A01/A02/A04/A05 pattern
# -----------------------------------------------------------------------
LOG_DIR="${ATLAS_BATCH_DIR}/logs/bam2fastq"
mkdir -p "${OUT_BARCODE_DIR}" "${LOG_DIR}"

sample_log="${LOG_DIR}/${sample_id}_${SLURM_JOB_ID}.log"
exec >"${sample_log}" 2>&1

echo "=========================================="
echo "[$(date)] BAM → FASTQ.gz (v2: plain headers)"
echo "Task:        ${TASK}"
echo "Barcode:     ${barcode}"
echo "Sample:      ${sample_id}"
echo "Input BAM:   ${INPUT_BAM}"
echo "Output:      ${OUTPUT_FASTQ_GZ}"
echo "Job:         ${SLURM_JOB_ID} / array ${SLURM_ARRAY_JOB_ID} task ${TASK}"
echo "Host:        $(hostname)"
echo "Threads:     ${SLURM_NTASKS:-1}"
echo "=========================================="

# Validate input
if [[ ! -s "${INPUT_BAM}" ]]; then
    echo "ERROR: input BAM empty or missing: ${INPUT_BAM}" >&2
    exit 1
fi

# Skip if already done
if [[ -s "${OUTPUT_FASTQ_GZ}" ]]; then
    echo "Output exists and non-empty — skipping: ${OUTPUT_FASTQ_GZ}"
    echo "Size: $(du -sh "${OUTPUT_FASTQ_GZ}" | cut -f1)"
    exit 0
fi

# -----------------------------------------------------------------------
# Run conversion
# -----------------------------------------------------------------------
module purge
module load samtools

# Prefer pigz (parallel gzip) if available; fall back to gzip.
if command -v pigz >/dev/null 2>&1; then
    GZ="pigz -p ${SLURM_NTASKS:-1}"
    GZ_LABEL="pigz (${SLURM_NTASKS:-1} threads)"
else
    GZ="gzip"
    GZ_LABEL="gzip (single-threaded)"
fi
echo "Compression: ${GZ_LABEL}"

echo "[$(date)] Running samtools fastq | ${GZ%% *}..."

# Plain FASTQ output:
#   -@   samtools decompression threads.
#   (no -T)  produces standard FASTQ headers (just the read ID).
#   To preserve all BAM tags in headers, add `-T '*'` — see header note.
samtools fastq -@ "${SLURM_NTASKS:-1}" "${INPUT_BAM}" \
    | ${GZ} > "${OUTPUT_FASTQ_GZ}"

# Verify output
if [[ ! -s "${OUTPUT_FASTQ_GZ}" ]]; then
    echo "ERROR: output empty: ${OUTPUT_FASTQ_GZ}" >&2
    exit 1
fi

# -----------------------------------------------------------------------
# Sanity report
# -----------------------------------------------------------------------
echo
echo "--- Output summary ---"
first_header=$(zcat "${OUTPUT_FASTQ_GZ}" | awk 'NR==1 {print; exit}' || true)
echo "First record header:"
echo "  ${first_header}"
echo "Output size:    $(du -sh "${OUTPUT_FASTQ_GZ}" | cut -f1)"
echo "Read count:     $(zcat "${OUTPUT_FASTQ_GZ}" | awk 'NR%4==1' | wc -l)"

# Cross-check against input BAM read count
bam_reads=$(samtools view -c "${INPUT_BAM}")
fq_reads=$(zcat "${OUTPUT_FASTQ_GZ}" | awk 'NR%4==1' | wc -l)
echo "BAM reads:      ${bam_reads}"
echo "FASTQ reads:    ${fq_reads}"
if [[ "${bam_reads}" != "${fq_reads}" ]]; then
    echo "WARN: read count mismatch — investigate" >&2
fi

module purge

echo
echo "[$(date)] Done: ${sample_id}"
echo
echo "NEXT:"
echo "  Batch 3 (diagnostic): compare A03 output against MinKNOW FASTQs"
echo "    - Read count:  zcat <minknow.fastq.gz> | awk 'NR%4==1' | wc -l"
echo "    - File size:   du -sh <minknow.fastq.gz>"
echo "    - Quality:     NanoPlot on both, side by side"
echo ""
echo "  Future batches (pipeline source): transfer to Ceres:"
echo "    scp -r ${OUT_BARCODE_DIR} \\"
echo "        ceres:\${CERES_BATCH_DIR}/00_Raw_Data/${barcode}/"
echo "  Then on Ceres: SKIP 01_concat (already 1 file per barcode);"
echo "    sbatch --array=1 scripts/02_porechop.sh"
