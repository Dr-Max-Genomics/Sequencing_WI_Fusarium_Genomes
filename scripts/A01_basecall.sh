#!/bin/bash -l
#SBATCH --job-name=Dor_Basecall
#SBATCH -A silage_microbiome
#SBATCH -p gpu-a100
#SBATCH --gres=gpu:a100:1
#SBATCH --qos=normal
#SBATCH -N 1
#SBATCH -n 40
#SBATCH -t 150:00:00
#SBATCH --mail-user=maxwell.chibuogwu@usda.gov
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH -o log/basecall.%j.%N.out
#SBATCH -e log/basecall.%j.%N.err

set -euo pipefail

# =======================================================================
# A01_basecall.sh   —   ATLAS GPU step (A-series)
# -----------------------------------------------------------------------
# Purpose : Dorado basecalling of POD5 → BAM, with move tables and a
#           summary TSV. This is the entry point for the A-series
#           workflow when you basecall yourself (vs MinKNOW basecalling).
# Cluster : ATLAS (GPU). Atlas and Ceres filesystems are NOT synced, so
#           paths are HARDCODED. Edit per batch.
# -----------------------------------------------------------------------
# A-series pipeline context:
#   A01_basecall   →   POD5 → calls.bam + summary.tsv  (THIS SCRIPT)
#   A02_demux      →   calls.bam → per-barcode BAMs
#   A03_bam2fastq  →   per-barcode BAMs → per-barcode fastq.gz
#         ↓  transfer to Ceres
#   Ceres: 01_concat is SKIPPED (A02 already split per barcode)
#          02_porechop → 03_dedup → 04_nanofilt → 05_nanoplot → ...
#         ↓  transfer filtered reads back to Atlas
#   Atlas: A04_dorado_corr (HERRO correction)
#         ↓  transfer corrected reads back to Ceres
#   Ceres: 06_flye_assemble (--nano-corr) → ...
#         ↓  transfer Flye assembly to Atlas
#   Atlas: A05_alignment_polish (uses calls.bam from THIS script + assembly)
# -----------------------------------------------------------------------
# Usage : sbatch A01_basecall.sh
#         (single non-array job; dorado handles internal parallelism)
# Output:
#   - ${BATCH_DIR}/A01_basecall/calls.bam       (with mv tag for polish)
#   - ${BATCH_DIR}/A01_basecall/summary.tsv     (per-read summary)
# Notes :
#   - --emit-moves: writes the move table 'mv' tag → enables move-aware
#     polishing models in A05 (significantly more accurate polish).
#   - --emit-summary: writes summary.tsv next to calls.bam — no need for
#     a separate 'dorado summary' job.
#   - --min-qscore 15: matches batch 1/2 methodology.
#   - NO --kit-name here: demux happens cleanly in A02 with full control
#     (e.g., --barcode-both-ends).
# =======================================================================

# -----------------------------------------------------------------------
# HARDCODED Atlas paths  (EDIT PER BATCH)
# -----------------------------------------------------------------------
ATLAS_BATCH_DIR="/90daydata/silage_microbiome/Max_Batch3"
POD5_DIR="${ATLAS_BATCH_DIR}/00_Raw_Data/pod5"        # input POD5 directory (recursive scan)
OUT_DIR="${ATLAS_BATCH_DIR}/A01_basecall"             # output for calls.bam + summary.tsv

OUT_BAM="${OUT_DIR}/calls.bam"
SUMMARY_TSV="${OUT_DIR}/summary.tsv"

# -----------------------------------------------------------------------
# Basecalling parameters  (match batch 1/2)
# -----------------------------------------------------------------------
MODEL="sup"                # auto-resolves to latest SUP model for the data
MIN_QSCORE=15

mkdir -p "${OUT_DIR}" log

echo "=========================================="
echo "[$(date)] dorado basecaller — ATLAS GPU"
echo "POD5 input:  ${POD5_DIR}"
echo "Model:       ${MODEL}"
echo "Min qscore:  ${MIN_QSCORE}"
echo "Output BAM:  ${OUT_BAM}"
echo "Summary:     ${SUMMARY_TSV}"
echo "Job:         ${SLURM_JOB_ID}"
echo "Host:        $(hostname)"
echo "GPU:         ${CUDA_VISIBLE_DEVICES:-unset}"
echo "=========================================="

# Validate input
if [[ ! -d "${POD5_DIR}" ]]; then
    echo "ERROR: POD5 directory not found: ${POD5_DIR}" >&2
    exit 1
fi
pod5_count=$(find "${POD5_DIR}" -name "*.pod5" | wc -l)
if [[ "${pod5_count}" -eq 0 ]]; then
    echo "ERROR: no .pod5 files found under ${POD5_DIR}" >&2
    exit 1
fi
echo "Found ${pod5_count} POD5 files (recursive)."

# Skip if already done
if [[ -s "${OUT_BAM}" ]]; then
    echo "Output BAM exists and non-empty — skipping: ${OUT_BAM}"
    echo "(Delete or rename to re-basecall.)"
    exit 0
fi

# -----------------------------------------------------------------------
# Run dorado basecaller
# -----------------------------------------------------------------------
module purge
module load dorado

echo "[$(date)] Starting basecalling..."

dorado basecaller "${MODEL}" "${POD5_DIR}" \
    --recursive \
    --device cuda:all \
    --emit-moves \
    --min-qscore "${MIN_QSCORE}" \
    --output-dir "${OUT_DIR}" \
    --emit-summary

# When --output-dir is used, dorado writes into a nested MinKNOW-style
# structure. Locate the produced BAM(s) and create a stable symlink.
# Pass-quality reads land under .../pass/, fail under .../fail/.
echo "[$(date)] Basecalling complete; collating outputs..."

# Find the primary pass BAM. If multiple were emitted (e.g., split by
# barcode/channel), merge them into one calls.bam.
module load samtools

mapfile -t PASS_BAMS < <(find "${OUT_DIR}" -path "*/pass/*.bam" -type f | sort)

if [[ ${#PASS_BAMS[@]} -eq 0 ]]; then
    # Some Dorado versions / configs may put the BAM at the top level.
    mapfile -t PASS_BAMS < <(find "${OUT_DIR}" -maxdepth 2 -name "*.bam" -type f | sort)
fi

if [[ ${#PASS_BAMS[@]} -eq 0 ]]; then
    echo "ERROR: no BAM files produced under ${OUT_DIR}" >&2
    find "${OUT_DIR}" -maxdepth 4 -type f >&2
    exit 1
elif [[ ${#PASS_BAMS[@]} -eq 1 ]]; then
    echo "One pass BAM found — symlinking as calls.bam"
    ln -sfn "${PASS_BAMS[0]}" "${OUT_BAM}"
else
    echo "Multiple pass BAMs (${#PASS_BAMS[@]}) — merging into calls.bam"
    samtools merge -@ "${SLURM_NTASKS:-4}" -f "${OUT_BAM}" "${PASS_BAMS[@]}"
fi

# Locate the summary TSV (dorado places it in the output dir root)
if [[ ! -s "${SUMMARY_TSV}" ]]; then
    found_summary=$(find "${OUT_DIR}" -maxdepth 2 -name "summary.tsv" -o -name "sequencing_summary*.tsv" | head -1)
    if [[ -n "${found_summary}" ]]; then
        ln -sfn "${found_summary}" "${SUMMARY_TSV}"
        echo "Linked summary: ${found_summary} → ${SUMMARY_TSV}"
    else
        echo "WARN: summary.tsv not found in ${OUT_DIR}" >&2
    fi
fi

# Sanity checks
echo
echo "--- Output sanity check ---"
if [[ -s "${OUT_BAM}" ]]; then
    echo "calls.bam size: $(du -sh "${OUT_BAM}" | cut -f1)"
    echo "calls.bam record count:"
    samtools view -c "${OUT_BAM}"
    echo "Move table 'mv' tag present?"
    mv_count=$(samtools view --keep-tag "mv" -c "${OUT_BAM}" || echo "0")
    total=$(samtools view -c "${OUT_BAM}")
    echo "  reads with 'mv' tag: ${mv_count} / ${total}"
    if [[ "${mv_count}" != "${total}" ]]; then
        echo "  WARN: not all reads have 'mv' tag — move-aware polish may fall back to base model" >&2
    fi
fi

if [[ -s "${SUMMARY_TSV}" ]]; then
    echo "summary.tsv lines: $(wc -l < "${SUMMARY_TSV}")"
fi

module purge

echo "[$(date)] Done."
echo
echo "NEXT: run A02_demux.sh to split calls.bam into per-barcode BAMs."
