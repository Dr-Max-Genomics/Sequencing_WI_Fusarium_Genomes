#!/bin/bash -l
#SBATCH --job-name=Align_Polish
#SBATCH -A silage_microbiome
#SBATCH -p gpu-a100
#SBATCH --gres=gpu:a100:4
#SBATCH --qos=normal
#SBATCH -N 1
#SBATCH -n 16
#SBATCH -t 10:00:00
#SBATCH --array=1-7
#SBATCH --mail-user=maxwell.chibuogwu@usda.gov
#SBATCH --mail-type=BEGIN,END,FAIL

set -euo pipefail
shopt -s nullglob

# =======================================================================
# A05_alignment_polish.sh   —   ATLAS GPU step (A-series)   [v2]
# -----------------------------------------------------------------------
# Purpose : Align per-barcode reads (from A02 demux) to the matching
#           Flye assembly, then polish with dorado polish. One isolate
#           per array task, one A100 GPU each.
# Cluster : ATLAS (GPU). Atlas and Ceres filesystems are NOT synced.
#           All paths are HARDCODED. Edit per batch.
# -----------------------------------------------------------------------
# A-series pipeline context:
#   A01  →  calls.bam (mv tags; canonical signal source)
#   A02  →  per-barcode BAMs (mv tags preserved; barcode = filename)
#   A05  →  align A02 BAM to assembly + polish     (THIS SCRIPT)
#         ↓  transfer polished FASTA to Ceres
#   Ceres: 07_Polished_Genome/{sample_id}_polished.fasta
# -----------------------------------------------------------------------
# Prerequisites (must exist before this script runs):
#   - ${A02_DEMUX_DIR}/*_barcodeXX.bam : per-barcode BAM from A02 demux
#   - ${ASSEMBLY_DIR}/{sample_id}_assembly.fasta : Flye assembly copied
#     from Ceres 07_Polished_Genome/ after 06_flye_assemble.sh ran.
# -----------------------------------------------------------------------
# Sandbox pattern:
#   06_Alignment_Polishing/{sample_id}/
#     aligned.bam       ← alignment of this barcode's reads to assembly
#     aligned.bam.bai
#   07_Polished_Genome/{sample_id}_polished.fasta  ← final output
# -----------------------------------------------------------------------
# Usage :
#   sbatch --array=1 A05_alignment_polish.sh    # test one isolate
#   sbatch --array=2-7 A05_alignment_polish.sh  # rest of batch
# =======================================================================

# -----------------------------------------------------------------------
# HARDCODED Atlas paths  (EDIT PER BATCH)
# -----------------------------------------------------------------------
ATLAS_BATCH_DIR="/90daydata/silage_microbiome/Max_Fus_Batch3"
A02_DEMUX_DIR="${ATLAS_BATCH_DIR}/A02_demux"
ASSEMBLY_DIR="${ATLAS_BATCH_DIR}/05_Genome_Assembly" # named assemblies from Ceres
MODEL_DIR="${ATLAS_BATCH_DIR}/dorado_models"
SANDBOX_DIR="${ATLAS_BATCH_DIR}/06_Alignment_Polishing"
POLISHED_DIR="${ATLAS_BATCH_DIR}/07_Polished_Genome"

# -----------------------------------------------------------------------
# Inline barcode → sample_id mapping  (EDIT PER BATCH)
# Array indices are repacked contiguously when barcodes are absent.
# Batch 3: barcode03 missing → task 3 = barcode04, +1 offset thereafter.
# -----------------------------------------------------------------------
declare -A SAMPLE_OF
declare -A BARCODE_OF
SAMPLE_OF[1]="Fus_Bar01"  ; BARCODE_OF[1]="barcode01"   # F. verticillioides
SAMPLE_OF[2]="Fus_Bar02"  ; BARCODE_OF[2]="barcode02"   # F. proliferatum
SAMPLE_OF[3]="Fus_Bar04"  ; BARCODE_OF[3]="barcode04"   # F. graminearum
SAMPLE_OF[4]="Fus_Bar05"  ; BARCODE_OF[4]="barcode05"   # F. annulatum
SAMPLE_OF[5]="Fus_Bar06"  ; BARCODE_OF[5]="barcode06"   # F. graminearum
SAMPLE_OF[6]="Fus_Bar07"  ; BARCODE_OF[6]="barcode07"   # F. graminearum
SAMPLE_OF[7]="Fus_Bar08"  ; BARCODE_OF[7]="barcode08"   # F. sporotrichioides

# -----------------------------------------------------------------------
# Resolve this task's sample
# -----------------------------------------------------------------------
TASK="${SLURM_ARRAY_TASK_ID}"
sample_id="${SAMPLE_OF[${TASK}]:-}"
barcode_label="${BARCODE_OF[${TASK}]:-}"

if [[ -z "${sample_id}" || -z "${barcode_label}" ]]; then
    echo "ERROR: no mapping for array task ${TASK}" >&2
    echo "Edit SAMPLE_OF / BARCODE_OF arrays and --array range." >&2
    exit 1
fi

# -----------------------------------------------------------------------
# Resolve A02 BAM via glob (filename pattern: <RG-hash>_SQK-NBD114-96_barcodeXX.bam)
# -----------------------------------------------------------------------
candidates=( "${A02_DEMUX_DIR}/"*"_${barcode_label}.bam" )

if [[ ${#candidates[@]} -eq 0 ]]; then
    echo "ERROR: no A02 BAM found for ${barcode_label} in ${A02_DEMUX_DIR}/" >&2
    echo "Expected a file matching: *_${barcode_label}.bam" >&2
    exit 1
elif [[ ${#candidates[@]} -gt 1 ]]; then
    echo "ERROR: multiple A02 BAMs match ${barcode_label}:" >&2
    printf '  %s\n' "${candidates[@]}" >&2
    exit 1
fi
READS_BAM="${candidates[0]}"

# -----------------------------------------------------------------------
# Paths
# -----------------------------------------------------------------------
ASSEMBLY="${ASSEMBLY_DIR}/${sample_id}_flye/${sample_id}_assembly.fasta"
SAMPLE_SANDBOX="${SANDBOX_DIR}/${sample_id}"
ALIGNED_BAM="${SAMPLE_SANDBOX}/aligned.bam"
POLISHED_FASTA="${POLISHED_DIR}/${sample_id}_polished.fasta"

# -----------------------------------------------------------------------
# Set up logging — match A01/A02/A04 pattern
# -----------------------------------------------------------------------
LOG_DIR="${ATLAS_BATCH_DIR}/logs/polish"
mkdir -p "${SAMPLE_SANDBOX}" "${POLISHED_DIR}" "${LOG_DIR}" "${MODEL_DIR}"

sample_log="${LOG_DIR}/${sample_id}_${SLURM_JOB_ID}.log"
exec >"${sample_log}" 2>&1

echo "=========================================="
echo "[$(date)] Alignment + polishing — ATLAS GPU (v2: A02 input)"
echo "Sample:        ${sample_id}"
echo "Barcode:       ${barcode_label}"
echo "Reads BAM:     ${READS_BAM}"
echo "Assembly:      ${ASSEMBLY}"
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
if [[ ! -s "${READS_BAM}" ]]; then
    echo "ERROR: A02 reads BAM is empty: ${READS_BAM}" >&2
    echo "Did this barcode actually have reads in the run?" >&2
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

# Quick mv-tag spot check — confirms A02 preserved the move table.
module purge
module load samtools

mv_count=$(samtools view --keep-tag "mv" -c "${READS_BAM}" 2>/dev/null || echo "0")
total=$(samtools view -c "${READS_BAM}" 2>/dev/null || echo "0")
echo "Read population: ${total} reads, ${mv_count} with 'mv' tag"
if [[ "${mv_count}" == "0" && "${total}" != "0" ]]; then
    echo "ERROR: no reads carry 'mv' tag — dorado polish cannot run move-aware model" >&2
    echo "Was A02 output produced from a non-move-table BAM?" >&2
    exit 1
fi

module load dorado

# -----------------------------------------------------------------------
# STEP 1 — Align reads to assembly
# Only this barcode's reads go in; no cross-barcode alignments to filter.
# -----------------------------------------------------------------------
if [[ ! -s "${ALIGNED_BAM}" ]]; then
    echo "[$(date)] STEP 1: Aligning ${barcode_label} reads to ${sample_id} assembly..."
    dorado aligner \
        --threads "${SLURM_NTASKS:-1}" \
        "${ASSEMBLY}" \
        "${READS_BAM}" \
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
    echo "(If this was produced by v1 of A05, DELETE IT and rerun — it contains all-barcode alignments.)"
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
# STEP 3 — Polish assembly with dorado polish
# No --RG filtering needed: input BAM is already barcode-specific.
# -----------------------------------------------------------------------
echo "[$(date)] STEP 3: Polishing assembly..."

dorado polish \
    "${ALIGNED_BAM}" \
    "${ASSEMBLY}" \
    --model "${MODEL_DIR}"
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
