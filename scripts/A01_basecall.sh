#!/bin/bash -l
#SBATCH --job-name=Dor_Basecall
#SBATCH -A silage_microbiome
#SBATCH -p gpu-a100
#SBATCH --gres=gpu:a100:6
#SBATCH --qos=normal
#SBATCH -N 1
#SBATCH -n 40
#SBATCH --mem=350G
#SBATCH -t 48:00:00
#SBATCH --mail-user=maxwell.chibuogwu@usda.gov
#SBATCH --mail-type=BEGIN,END,FAIL

set -euo pipefail

# =======================================================================
# A01_basecall.sh   —   ATLAS GPU step (A-series)
# -----------------------------------------------------------------------
# Purpose : Dorado basecalling of POD5 → BAM with move tables and a
#           summary TSV. Single-job, multi-GPU on Atlas.
# Cluster : ATLAS GPU (gpu-a100 partition). Paths HARDCODED — Atlas and
#           Ceres are NOT synced.
# -----------------------------------------------------------------------
# A-series pipeline:
#   A01 basecall    POD5 → calls.bam (mv tag) + summary.tsv   ← THIS SCRIPT
#   A02 demux       calls.bam → per-barcode BAMs
#   A03 bam2fastq   per-barcode BAMs → per-barcode fastq.gz
#         ↓ transfer to Ceres
#   Ceres: 02→05 preprocessing
#         ↓ transfer to Atlas
#   A04 correct     filtered fastq → corrected fasta (HERRO)
#         ↓ transfer to Ceres
#   Ceres: 06 Flye → 07 BUSCO
#         ↓ transfer assembly to Atlas
#   A05 align+polish  per-barcode BAM (from A02) + assembly → polished
# -----------------------------------------------------------------------
# Resources :
#   --gres=gpu:a100:5    5 of 8 A100s on one node. gpu-a100 partition
#                        has 3 nodes × 8 GPUs = 24 total. Requesting 5
#                        leaves room on the node for other users and
#                        queues faster than --gres=gpu:a100:8.
#   -n 40                40 of 128 cores. Basecalling is GPU-bound;
#                        cores handle chunk dispatch.
#   --mem=600G           ~1/3 of the 2TB on these nodes.
#   -t 48:00:00          Max walltime allowed on gpu-a100.
#
# Alternative — switch to gpu-l40s if queue is long:
#   #SBATCH -p gpu-l40s
#   #SBATCH --gres=gpu:l40s:4
# (12 nodes × 4 L40S = 48 GPUs; typically shorter queue than gpu-a100)
# -----------------------------------------------------------------------
# Notes :
#   - --emit-moves writes the 'mv' tag → enables move-aware polish in A05.
#   - --models-directory places downloaded model in a persistent location
#     so it's reused across runs and shared with A04's herro model.
#   - dorado basecaller has NO --emit-summary flag. Summary is produced
#     by a separate 'dorado summary' command after basecalling.
#   - --device cuda:all uses all visible GPUs. With --gres=gpu:a100:5
#     SLURM exposes 5 GPUs to the job as cuda:0..cuda:4.
#   - NO --kit-name here. Demux happens in A02 with --barcode-both-ends.
#     This produces ONE calls.bam with a single combined @RG.
# =======================================================================

# -----------------------------------------------------------------------
# HARDCODED Atlas paths  (EDIT PER BATCH)
# -----------------------------------------------------------------------
ATLAS_BATCH_DIR="/90daydata/silage_microbiome/Max_Fus_Batch3"
POD5_DIR="${ATLAS_BATCH_DIR}/00_Raw_Data/pod5"
OUT_DIR="${ATLAS_BATCH_DIR}/A01_basecall"
MODEL_DIR="${ATLAS_BATCH_DIR}/dorado_models"     # shared with A04 herro model
LOG_DIR_BASE="${ATLAS_BATCH_DIR}/logs"
LOG_DIR="${LOG_DIR_BASE}/basecall"

# Outputs we'll produce
OUT_BAM="${OUT_DIR}/calls.bam"                   # stable name (symlink → timestamped file)
SUMMARY_TSV="${OUT_DIR}/summary.tsv"

# -----------------------------------------------------------------------
# Basecalling parameters
# -----------------------------------------------------------------------
MODEL="sup"
MIN_QSCORE=15

# -----------------------------------------------------------------------
# Set up logging — match A04's pattern: ${ATLAS_BATCH_DIR}/logs/<step>/
# -----------------------------------------------------------------------
mkdir -p "${OUT_DIR}" "${MODEL_DIR}" "${LOG_DIR}"
log_file="${LOG_DIR}/A01_basecall_${SLURM_JOB_ID}.log"
exec >"${log_file}" 2>&1

echo "=========================================="
echo "[$(date)] dorado basecaller — ATLAS GPU"
echo "POD5 input:    ${POD5_DIR}"
echo "Model:         ${MODEL}"
echo "Min qscore:    ${MIN_QSCORE}"
echo "Models dir:    ${MODEL_DIR}"
echo "Output dir:    ${OUT_DIR}"
echo "Output BAM:    ${OUT_BAM}"
echo "Summary TSV:   ${SUMMARY_TSV}"
echo "Job:           ${SLURM_JOB_ID}"
echo "Host:          $(hostname)"
echo "GPUs assigned: ${CUDA_VISIBLE_DEVICES:-unset}"
echo "Cores:         ${SLURM_NTASKS:-?}"
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

# Skip if already done — resolve symlink to avoid stale-link false positives
if [[ -L "${OUT_BAM}" ]]; then
    resolved=$(readlink -f "${OUT_BAM}" || true)
    if [[ -n "${resolved}" && -s "${resolved}" ]]; then
        echo "Output BAM symlink exists and target is non-empty — skipping."
        echo "  ${OUT_BAM} → ${resolved}"
        echo "(Delete or rename to re-basecall.)"
        exit 0
    fi
elif [[ -s "${OUT_BAM}" ]]; then
    echo "Output BAM exists and non-empty — skipping: ${OUT_BAM}"
    exit 0
fi

# -----------------------------------------------------------------------
# STEP 1 — Run dorado basecaller
# -----------------------------------------------------------------------
module purge
module load dorado

echo "[$(date)] Starting basecalling..."

# With --output-dir, dorado writes a single file:  ${OUT_DIR}/calls_<timestamp>.bam
dorado basecaller "${MODEL}" "${POD5_DIR}" \
    --recursive \
    --device cuda:all \
    --emit-moves \
    --min-qscore "${MIN_QSCORE}" \
    --models-directory "${MODEL_DIR}" \
    --output-dir "${OUT_DIR}"

echo "[$(date)] Basecalling complete."

# -----------------------------------------------------------------------
# Locate the single calls_*.bam and symlink as calls.bam (stable name for A02)
# -----------------------------------------------------------------------
mapfile -t emitted < <(find "${OUT_DIR}" -maxdepth 1 -name "calls_*.bam" -type f | sort)

if [[ ${#emitted[@]} -eq 0 ]]; then
    echo "ERROR: no calls_*.bam found in ${OUT_DIR}" >&2
    ls -la "${OUT_DIR}" >&2
    exit 1
elif [[ ${#emitted[@]} -eq 1 ]]; then
    ln -sfn "$(basename "${emitted[0]}")" "${OUT_BAM}"
    echo "Symlinked: ${OUT_BAM} → ${emitted[0]}"
else
    echo "WARN: multiple calls_*.bam found (${#emitted[@]}); using newest:" >&2
    printf '  %s\n' "${emitted[@]}" >&2
    ln -sfn "$(basename "${emitted[-1]}")" "${OUT_BAM}"
fi

# -----------------------------------------------------------------------
# STEP 2 — Generate summary.tsv via separate 'dorado summary'
# (dorado basecaller has no --emit-summary flag — that's only on demux)
# -----------------------------------------------------------------------
echo
echo "[$(date)] Generating summary.tsv..."
dorado summary "${OUT_BAM}" > "${SUMMARY_TSV}"

if [[ ! -s "${SUMMARY_TSV}" ]]; then
    echo "WARN: summary.tsv empty after dorado summary" >&2
else
    echo "summary.tsv lines: $(wc -l < "${SUMMARY_TSV}")"
fi

# -----------------------------------------------------------------------
# Sanity checks
# -----------------------------------------------------------------------
module load samtools

echo
echo "--- Output sanity check ---"
real_bam=$(readlink -f "${OUT_BAM}")
echo "calls.bam → ${real_bam}"
echo "Size:      $(du -sh "${real_bam}" | cut -f1)"
total_reads=$(samtools view -c "${OUT_BAM}")
echo "Reads:     ${total_reads}"

# Verify 'mv' tag presence by peeking at the first record.
# Use awk to read one line and exit — safer than 'head -1' because awk's
# main loop consumes input cleanly before the 'exit' fires, avoiding the
# SIGPIPE-to-samtools issue (which under set -o pipefail can cause exit
# 141 or 142 even though basecalling itself succeeded).
# The '|| true' is belt-and-suspenders against any residual signal.
first_record_tags=$(samtools view "${OUT_BAM}" 2>/dev/null \
    | awk 'NR==1 {print; exit}' || true)
first_record_tags="${first_record_tags#$'\t'}"  # strip leading tab if any

if [[ "${first_record_tags}" == *"mv:"* ]]; then
    echo "Move table 'mv' tag: PRESENT (move-aware polish will work in A05)"
else
    echo "WARN: 'mv' tag NOT found in first record" >&2
    echo "Polish in A05 will fall back to a non-move-aware model." >&2
fi

module purge

echo
echo "[$(date)] Done."
echo "Outputs:"
echo "  ${OUT_BAM}"
echo "  ${SUMMARY_TSV}"
echo
echo "NEXT: sbatch A02_demux.sh"
