#!/bin/bash
#SBATCH --job-name=Dor_Correction
#SBATCH -A silage_microbiome
#SBATCH -p gpu-a100
#SBATCH --gres=gpu:a100:1
#SBATCH --qos=normal
#SBATCH -N 1
#SBATCH -n 16
#SBATCH -t 150:00:00
#SBATCH --array=1-7
#SBATCH --mail-user=maxwell.chibuogwu@usda.gov
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH -o log/dorcorr.%A_%a.%N.out
#SBATCH -e log/dorcorr.%A_%a.%N.err

set -euo pipefail

# =======================================================================
# A04_dorado_corr.sh   —   ATLAS GPU step (A-series)
# -----------------------------------------------------------------------
# Purpose : HERRO read correction (dorado correct) on filtered reads,
#           one isolate per array task, one A100 GPU each.
# Cluster : ATLAS (GPU). NOT Ceres. Atlas and Ceres filesystems are NOT
#           synced, so all paths here are HARDCODED (no repo/paths.sh,
#           no manifest). Edit BARCODES and paths per batch.
# -----------------------------------------------------------------------
# Workflow context (dual-path pipeline — see README):
#   Ceres: 01_concat .. 04_nanofilt .. 05a_nanoplot  (filtered reads)
#     ↓  scp filtered reads  03_Trimmed_Data/{sample}.fastq  →  Atlas
#   ATLAS: THIS SCRIPT — dorado correct → corrected FASTA
#     ↓  scp corrected reads back to Ceres 03_Trimmed_Data/corrected_reads/
#   Ceres: 05b_nanoplot (QC corrected) → 06_flye_assemble (--nano-corr)
# -----------------------------------------------------------------------
# Usage :
#   sbatch --array=1 A04_dorado_corr.sh        # test one isolate
#   sbatch --array=2-7 A04_dorado_corr.sh      # rest of batch
#   (or sbatch --array=1-7 — safe; see HERRO note below)
# Notes :
#   - dorado correct takes FASTQ in, outputs FASTA.
#   - dorado correct auto-grabs available compute; one GPU per task here.
#   - Adjust SAMPLES array and --array range to match your batch.
#   - HERRO MODEL: this script pre-stages the herro-v1 model into a shared
#     dir under a flock guard, so concurrent array tasks never race to
#     download it. The first task to acquire the lock downloads the model;
#     the rest wait, then reuse it. dorado correct is called with
#     --model-path so it never auto-downloads mid-run. This makes
#     launching all 7 tasks at once SAFE — no need to stagger.
# =======================================================================

# -----------------------------------------------------------------------
# HARDCODED Atlas paths  (EDIT PER BATCH)
# -----------------------------------------------------------------------
ATLAS_BATCH_DIR="/90daydata/silage_microbiome/Max_Batch3"
INPUT_DIR="${ATLAS_BATCH_DIR}/03_Trimmed_Data"               # filtered reads from Ceres
OUTPUT_DIR="${ATLAS_BATCH_DIR}/03_Trimmed_Data/corrected_reads"
LOG_DIR="${ATLAS_BATCH_DIR}/logs/dorado_correct"

# -----------------------------------------------------------------------
# Inline sample list  (EDIT PER BATCH)
# Index by array task ID. sample_id values must match the filtered-read
# filenames transferred from Ceres: ${INPUT_DIR}/${sample_id}.fastq
# Order matches batch_2026-May manifest (barcode03 absent).
# -----------------------------------------------------------------------
SAMPLES=(
    ""              # index 0 unused (arrays are 1-based here)
    "Fus_Bar01"     # task 1  — barcode01  F. verticillioides
    "Fus_Bar02"     # task 2  — barcode02  F. proliferatum
    "Fus_Bar04"     # task 3  — barcode04  F. graminearum
    "Fus_Bar05"     # task 4  — barcode05  F. annulatum
    "Fus_Bar06"     # task 5  — barcode06  F. graminearum
    "Fus_Bar07"     # task 6  — barcode07  F. graminearum
    "Fus_Bar08"     # task 7  — barcode08  F. sporotrichioides
)

sample_id="${SAMPLES[${SLURM_ARRAY_TASK_ID}]:-}"
if [[ -z "${sample_id}" ]]; then
    echo "ERROR: no sample for array task ${SLURM_ARRAY_TASK_ID}" >&2
    echo "Check the SAMPLES array and --array range." >&2
    exit 1
fi

# -----------------------------------------------------------------------
# Per-sample paths
# -----------------------------------------------------------------------
INPUT_FASTQ="${INPUT_DIR}/${sample_id}.fastq"
OUTPUT_FASTA="${OUTPUT_DIR}/corrected_${sample_id}.fasta"

mkdir -p "${OUTPUT_DIR}" "${LOG_DIR}" log

# Per-sample log (in addition to SLURM -o/-e above)
sample_log="${LOG_DIR}/${sample_id}.log"
exec >>"${sample_log}" 2>&1

echo "=========================================="
echo "[$(date)] dorado correct (HERRO)  — ATLAS GPU"
echo "Sample:     ${sample_id}"
echo "Input:      ${INPUT_FASTQ}"
echo "Output:     ${OUTPUT_FASTA}"
echo "Job:        ${SLURM_JOB_ID} / array ${SLURM_ARRAY_JOB_ID} task ${SLURM_ARRAY_TASK_ID}"
echo "Host:       $(hostname)"
echo "GPU:        ${CUDA_VISIBLE_DEVICES:-unset}"
echo "=========================================="

# Validate input
if [[ ! -s "${INPUT_FASTQ}" ]]; then
    echo "ERROR: input not found or empty: ${INPUT_FASTQ}" >&2
    echo "Did you transfer the filtered reads from Ceres to Atlas?" >&2
    exit 1
fi

# Skip if already done
if [[ -s "${OUTPUT_FASTA}" ]]; then
    echo "Corrected output exists and non-empty — skipping: ${OUTPUT_FASTA}"
    exit 0
fi

# -----------------------------------------------------------------------
# Run dorado correct
# -----------------------------------------------------------------------
module purge
module load dorado

# -----------------------------------------------------------------------
# HERRO model — pre-stage once into a shared path, guarded by a file lock,
# so concurrent array tasks never race to download it.
#
# Strategy:
#   1. Model lives at ${MODEL_DIR}/herro-v1 (shared across all tasks).
#   2. Before correcting, acquire an exclusive flock on a lockfile.
#   3. The first task to get the lock downloads the model (if absent);
#      all other tasks block on the lock, then find the model present
#      and skip the download.
#   4. dorado correct is then called with --model-path so it never
#      attempts its own auto-download.
# This makes the script safe even if all 7 tasks launch simultaneously.
# -----------------------------------------------------------------------
MODEL_DIR="${ATLAS_BATCH_DIR}/dorado_models"
MODEL_PATH="${MODEL_DIR}/herro-v1"
LOCKFILE="${MODEL_DIR}/.herro_download.lock"

mkdir -p "${MODEL_DIR}"

echo "[$(date)] Ensuring HERRO model is present (flock-guarded)..."
# fd 200 is the lock handle; flock blocks until the lock is free.
exec 200>"${LOCKFILE}"
flock 200
if [[ ! -e "${MODEL_PATH}" ]]; then
    echo "[$(date)] Model absent — downloading herro-v1 to ${MODEL_DIR}"
    # Download into MODEL_DIR; dorado places the model dir here.
    ( cd "${MODEL_DIR}" && dorado download --model herro-v1 )
    if [[ ! -e "${MODEL_PATH}" ]]; then
        echo "ERROR: herro-v1 model not found at ${MODEL_PATH} after download" >&2
        echo "Check 'dorado download' output / network on Atlas." >&2
        flock -u 200
        exit 1
    fi
else
    echo "[$(date)] Model already present at ${MODEL_PATH} — skipping download"
fi
flock -u 200   # release lock before the heavy compute stage
echo "[$(date)] Model ready."

echo "[$(date)] Running dorado correct..."
dorado correct \
    --model-path "${MODEL_PATH}" \
    "${INPUT_FASTQ}" > "${OUTPUT_FASTA}"

# Verify output
if [[ ! -s "${OUTPUT_FASTA}" ]]; then
    echo "ERROR: dorado correct finished but output is empty: ${OUTPUT_FASTA}" >&2
    exit 1
fi

module purge

echo "[$(date)] Done: ${sample_id}"
echo "Output FASTA: ${OUTPUT_FASTA}"
echo "Output size:  $(du -sh "${OUTPUT_FASTA}" | cut -f1)"
echo
echo "NEXT: transfer ${OUTPUT_FASTA} back to Ceres:"
echo "  ${ATLAS_BATCH_DIR}/03_Trimmed_Data/corrected_reads/  →  Ceres 03_Trimmed_Data/corrected_reads/"
echo "Then run 05b_nanoplot (QC) and 06_flye_assemble (--nano-corr) on Ceres."
