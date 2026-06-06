#!/bin/bash -l
#SBATCH --job-name=Align_Polish
#SBATCH -A silage_microbiome
#SBATCH -p gpu-a100
#SBATCH --gres=gpu:a100:5
#SBATCH --qos=normal
#SBATCH -N 1
#SBATCH -n 16
#SBATCH -t 10:00:00
#SBATCH --array=1-7
#SBATCH --mail-user=maxwell.chibuogwu@usda.gov
#SBATCH --mail-type=BEGIN,END,FAIL

set -euo pipefail

# =======================================================================
# A05_alignment_polish.sh   —   ATLAS GPU step (A-series)
# -----------------------------------------------------------------------
# Purpose : Align basecalled reads (calls.bam from A01) to the Flye
#           assembly, then polish with dorado polish. One isolate per
#           array task, one A100 GPU each.
# Cluster : ATLAS (GPU). Atlas and Ceres filesystems are NOT synced.
#           All paths are HARDCODED. Edit per batch.
# -----------------------------------------------------------------------
# A-series pipeline context:
#   A01  →  calls.bam (with mv tag; used again here — don't delete it)
#   A05  →  align + polish                          (THIS SCRIPT)
#         ↓  transfer polished FASTA to Ceres
#   Ceres: 07_Polished_Genome/{sample_id}_polished.fasta
#          → 07_busco_eval → 08_sort_earlgrey_mask → ...
# -----------------------------------------------------------------------
# Prerequisites (must exist before this script runs):
#   - ${A01_BAM}        : calls.bam from A01 (aligned BAM with mv tags)
#   - ${ASSEMBLY_DIR}/{sample_id}_assembly.fasta : Flye assembly copied
#     from Ceres 07_Polished_Genome/ after 06_flye_assemble.sh ran.
#     Note: Flye always outputs assembly.fasta; 06_flye_assemble.sh
#     renames it to {sample_id}_assembly.fasta before transfer.
# -----------------------------------------------------------------------
# Sandbox pattern:
#   06_Alignment_Polishing/{sample_id}/  ← per-sample working directory
#     aligned.bam                        ← alignment output
#     aligned.bam.bai                    ← BAM index
#   07_Polished_Genome/{sample_id}_polished.fasta  ← final output
# -----------------------------------------------------------------------
# Usage :
#   sbatch --array=1 A05_alignment_polish.sh    # test one isolate
#   sbatch --array=2-7 A05_alignment_polish.sh  # rest of batch
# =======================================================================

# -----------------------------------------------------------------------
# HARDCODED Atlas paths  (EDIT PER BATCH)
# -----------------------------------------------------------------------
ATLAS_BATCH_DIR="/90daydata/silage_microbiome/Max_Batch3"
A01_BAM="${ATLAS_BATCH_DIR}/A01_basecall/calls.bam"   # move-table-aware BAM
ASSEMBLY_DIR="${ATLAS_BATCH_DIR}/05_Genome_Assembly"  # named assemblies from Ceres
SANDBOX_DIR="${ATLAS_BATCH_DIR}/06_Alignment_Polishing"
POLISHED_DIR="${ATLAS_BATCH_DIR}/07_Polished_Genome"

# -----------------------------------------------------------------------
# Inline barcode → sample_id mapping  (EDIT PER BATCH)
# Matches batch_2026-May manifest. barcode03 absent.
# -----------------------------------------------------------------------
declare -A SAMPLE_OF
SAMPLE_OF[1]="Fus_Bar01"   # barcode01  F. verticillioides
SAMPLE_OF[2]="Fus_Bar02"   # barcode02  F. proliferatum
SAMPLE_OF[3]="Fus_Bar04"   # barcode04  F. graminearum
SAMPLE_OF[4]="Fus_Bar05"   # barcode05  F. annulatum
SAMPLE_OF[5]="Fus_Bar06"   # barcode06  F. graminearum
SAMPLE_OF[6]="Fus_Bar07"   # barcode07  F. graminearum
SAMPLE_OF[7]="Fus_Bar08"   # barcode08  F. sporotrichioides

# -----------------------------------------------------------------------
# Resolve this task's sample
# -----------------------------------------------------------------------
TASK="${SLURM_ARRAY_TASK_ID}"
sample_id="${SAMPLE_OF[${TASK}]:-}"

if [[ -z "${sample_id}" ]]; then
    echo "ERROR: no mapping for array task ${TASK}" >&2
    echo "Edit SAMPLE_OF array and --array range." >&2
    exit 1
fi

# -----------------------------------------------------------------------
# Paths
# -----------------------------------------------------------------------
ASSEMBLY="${ASSEMBLY_DIR}/${sample_id}_assembly.fasta"
SAMPLE_SANDBOX="${SANDBOX_DIR}/${sample_id}"
ALIGNED_BAM="${SAMPLE_SANDBOX}/aligned.bam"
POLISHED_FASTA="${POLISHED_DIR}/${sample_id}_polished.fasta"

# -----------------------------------------------------------------------
# Set up logging — match A01/A04 pattern: ${ATLAS_BATCH_DIR}/logs/<step>/
# -----------------------------------------------------------------------
LOG_DIR_BASE="${ATLAS_BATCH_DIR}/logs"
LOG_DIR="${LOG_DIR_BASE}/polish"
mkdir -p "${SAMPLE_SANDBOX}" "${POLISHED_DIR}" "${LOG_DIR}"

sample_log="${LOG_DIR}/${sample_id}.log"
exec >"${sample_log}" 2>&1

echo "=========================================="
echo "[$(date)] Alignment + polishing — ATLAS GPU"
echo "Sample:        ${sample_id}"
echo "Assembly:      ${ASSEMBLY}"
echo "Reads BAM:     ${A01_BAM}"
echo "Aligned BAM:   ${ALIGNED_BAM}"
echo "Polished out:  ${POLISHED_FASTA}"
echo "Job:           ${SLURM_JOB_ID} / array ${SLURM_ARRAY_JOB_ID} task ${TASK}"
echo "Host:          $(hostname)"
echo "GPU:           ${CUDA_VISIBLE_DEVICES:-unset}"
echo "Threads:       ${SLURM_NTASKS:-1}"
echo "=========================================="

# -----------------------------------------------------------------------
# Validate inputs
# -----------------------------------------------------------------------
if [[ ! -s "${A01_BAM}" ]]; then
    echo "ERROR: reads BAM not found or empty: ${A01_BAM}" >&2
    echo "Did A01_basecall.sh complete successfully?" >&2
    exit 1
fi

if [[ ! -s "${ASSEMBLY}" ]]; then
    echo "ERROR: assembly not found or empty: ${ASSEMBLY}" >&2
    echo "Did 06_flye_assemble.sh run on Ceres and was the assembly" >&2
    echo "transferred to Atlas at ${ASSEMBLY_DIR}/${sample_id}_assembly.fasta ?" >&2
    exit 1
fi

# Skip if already done
if [[ -s "${POLISHED_FASTA}" ]]; then
    echo "Polished assembly exists — skipping: ${POLISHED_FASTA}"
    exit 0
fi

# -----------------------------------------------------------------------
# Load modules
# -----------------------------------------------------------------------
module purge
module load dorado
module load samtools

# -----------------------------------------------------------------------
# STEP 1 — Align reads to assembly
# -----------------------------------------------------------------------
# dorado aligner accepts a BAM of reads + a FASTA reference.
# Pipe directly into samtools sort to avoid a large unsorted intermediate.
# -----------------------------------------------------------------------
if [[ ! -s "${ALIGNED_BAM}" ]]; then
    echo "[$(date)] STEP 1: Aligning reads to assembly..."
    dorado aligner \
        --threads "${SLURM_NTASKS:-1}" \
        "${ASSEMBLY}" \
        "${A01_BAM}" \
    | samtools sort \
        --threads "${SLURM_NTASKS:-1}" \
        -o "${ALIGNED_BAM}"

    if [[ ! -s "${ALIGNED_BAM}" ]]; then
        echo "ERROR: aligned BAM empty after alignment: ${ALIGNED_BAM}" >&2
        exit 1
    fi
    echo "[$(date)] Alignment done. BAM size: $(du -sh "${ALIGNED_BAM}" | cut -f1)"
else
    echo "Aligned BAM already exists — skipping alignment: ${ALIGNED_BAM}"
fi

# -----------------------------------------------------------------------
# STEP 2 — Index aligned BAM
# -----------------------------------------------------------------------
if [[ ! -f "${ALIGNED_BAM}.bai" ]]; then
    echo "[$(date)] STEP 2: Indexing BAM..."
    samtools index -@ "${SLURM_NTASKS:-1}" "${ALIGNED_BAM}"
    echo "[$(date)] Indexing done."
else
    echo "BAM index already exists — skipping."
fi

# -----------------------------------------------------------------------
# STEP 3 — Detect RG tag for this barcode
# The aligned BAM may contain reads from multiple barcodes (all reads
# from calls.bam were aligned). The RG (read group) tag identifies which
# reads belong to this specific barcode/sample. Passing --RG ensures
# dorado polish only uses reads from the correct barcode.
# -----------------------------------------------------------------------
echo "[$(date)] STEP 3: Detecting read group (RG) for ${sample_id}..."

# Extract the barcode number from sample_id (Fus_Bar01 → barcode01)
# The RG tag in the BAM header encodes the barcode from demuxing.
barcode_num=$(echo "${sample_id}" | sed 's/Fus_Bar//' | awk '{printf "%02d", $1}')
barcode_label="barcode${barcode_num}"

RG=$(samtools view -H "${ALIGNED_BAM}" \
    | grep "^@RG" \
    | grep -i "${barcode_label}" \
    | awk '{for(i=1;i<=NF;i++) if($i ~ /^ID:/) print substr($i,4)}' \
    | head -1)

if [[ -z "${RG}" ]]; then
    echo "WARN: could not auto-detect RG for ${barcode_label}" >&2
    echo "Available @RG lines in BAM header:" >&2
    samtools view -H "${ALIGNED_BAM}" | grep "^@RG" >&2
    echo "Proceeding WITHOUT --RG flag (will use all reads in BAM)" >&2
    echo "This is acceptable if only this barcode's reads are in the BAM." >&2
    USE_RG=""
else
    echo "Detected RG: ${RG}"
    USE_RG="--RG ${RG}"
fi

# -----------------------------------------------------------------------
# STEP 4 — Polish assembly with dorado polish
# Uses the move-table-aware BAM from A01 (mv tags) to enable the
# more accurate polishing model.
# -----------------------------------------------------------------------
echo "[$(date)] STEP 4: Polishing assembly..."

# shellcheck disable=SC2086
dorado polish \
    ${USE_RG} \
    "${ALIGNED_BAM}" \
    "${ASSEMBLY}" \
    > "${POLISHED_FASTA}"

if [[ ! -s "${POLISHED_FASTA}" ]]; then
    echo "ERROR: polished output empty: ${POLISHED_FASTA}" >&2
    exit 1
fi

# -----------------------------------------------------------------------
# Sanity check
# -----------------------------------------------------------------------
echo
echo "--- Polish summary ---"
echo "Polished FASTA: ${POLISHED_FASTA}"
echo "Size:           $(du -sh "${POLISHED_FASTA}" | cut -f1)"
echo "Sequences:      $(grep -c "^>" "${POLISHED_FASTA}")"

module purge

echo
echo "[$(date)] Done: ${sample_id}"
echo
echo "NEXT: transfer polished assembly to Ceres 07_Polished_Genome/:"
echo "  scp ${POLISHED_FASTA} \\"
echo "      ceres:/90daydata/silage_microbiome/max_seq/batch_2026-May/07_Polished_Genome/${sample_id}_polished.fasta"
echo "Then: sbatch --array=1 scripts/07_busco_eval.sh"
