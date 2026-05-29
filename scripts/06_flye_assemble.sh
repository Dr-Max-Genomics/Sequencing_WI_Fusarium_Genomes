#!/usr/bin/env bash
#SBATCH -A silage_microbiome
#SBATCH -N 1
#SBATCH -n 40
#SBATCH --mem=1280G
#SBATCH -p ceres
#SBATCH -t 1-0
#SBATCH --job-name=flye
#SBATCH --array=1-7
#SBATCH --output=/dev/null

set -euo pipefail

# -----------------------------------------------------------------------
# 06_flye_assemble.sh
# Purpose : De novo genome assembly with Flye, one isolate per array task.
# Usage   : sbatch --array=1 scripts/06_flye_assemble.sh     # test one
#           sbatch --array=2-7 scripts/06_flye_assemble.sh   # rest of batch
# Input   : 03_Trimmed_Data/corrected_reads/corrected_{sample_id}.fasta
#           (HERRO-corrected reads from A04_dorado_corr.sh, run on Atlas)
# Output  : 05_Genome_Assembly/{sample_id}_flye/assembly.fasta
#
# READ TYPE: --nano-corr
#   Reads were corrected with dorado correct (HERRO algorithm) on Atlas
#   before assembly. --nano-corr is the correct flag for reads that have
#   passed through a dedicated correction tool. This matches the batch 1/2
#   methodology. See CHANGELOG v1.8.
#
#   NOTE: If assembling UNCORRECTED Dorado SUP reads (no dorado correct
#   step), use --nano-hq instead and point INPUT at the filtered reads in
#   03_Trimmed_Data/{sample_id}.fastq.
#
# PARALLELISM NOTE:
#   This is an ARRAY job (across-job parallelism): each task assembles a
#   different isolate concurrently. Each task also uses Flye's internal
#   multi-threading (within-job parallelism) via --threads ${SLURM_NTASKS}.
#   Requesting --array=1-7 with -n 40 asks for up to 7x40 = 280 cores at
#   once; SLURM will stagger tasks if the cluster can't grant all at once.
#   Queued tasks start automatically as others finish — no action needed.
# -----------------------------------------------------------------------

PROJECT_ROOT="${PROJECT_ROOT:-/project/silage_microbiome/max.chi/fusarium_sequencing}"
source "${PROJECT_ROOT}/config/paths.sh"

# Genome size and coverage — overridable via export before submission
GENOME_SIZE="${GENOME_SIZE:-50m}"
ASM_COVERAGE="${ASM_COVERAGE:-100}"

module load flye

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
INPUT="${TRIMMED_DIR}/corrected_reads/corrected_${sample_id}.fasta"
OUTDIR="${ASSEMBLY_DIR}/${sample_id}_flye"
ASSEMBLY_OUT="${OUTDIR}/assembly.fasta"

mkdir -p "${ASSEMBLY_DIR}" "${LOG_DIR}/flye"
log_file="${LOG_DIR}/flye/${sample_id}.log"
exec >"${log_file}" 2>&1

echo "=========================================="
echo "[$(date)] Flye assembly"
echo "Barcode:     ${barcode}"
echo "Sample:      ${sample_id}"
echo "Read type:   --nano-corr (HERRO-corrected)"
echo "Genome size: ${GENOME_SIZE}"
echo "Coverage:    ${ASM_COVERAGE}"
echo "Input:       ${INPUT}"
echo "Output dir:  ${OUTDIR}"
echo "Threads:     ${SLURM_NTASKS}"
echo "Manifest:    ${MANIFEST}"
echo "Job ID:      ${SLURM_JOB_ID} / task ${SLURM_ARRAY_TASK_ID}"
echo "Host:        $(hostname)"
echo "=========================================="

# Validate input
if [[ ! -s "${INPUT}" ]]; then
    echo "ERROR: input not found or empty: ${INPUT}" >&2
    echo "Did A04_dorado_corr.sh run on Atlas and were corrected reads" >&2
    echo "transferred back to Ceres 03_Trimmed_Data/corrected_reads/ ?" >&2
    exit 1
fi

# Skip if already done
if [[ -s "${ASSEMBLY_OUT}" ]]; then
    echo "Assembly already exists — skipping: ${ASSEMBLY_OUT}"
    exit 0
fi

# -----------------------------------------------------------------------
# Run Flye
# -----------------------------------------------------------------------
echo "[$(date)] Running Flye (--nano-corr)..."

flye \
    --nano-corr "${INPUT}" \
    --threads "${SLURM_NTASKS}" \
    --genome-size "${GENOME_SIZE}" \
    --asm-coverage "${ASM_COVERAGE}" \
    --out-dir "${OUTDIR}"

# Verify output
if [[ ! -s "${ASSEMBLY_OUT}" ]]; then
    echo "ERROR: Flye finished but assembly.fasta is missing or empty: ${ASSEMBLY_OUT}" >&2
    exit 1
fi

echo "[$(date)] Done: ${sample_id}"
echo "Assembly: ${ASSEMBLY_OUT}"
echo "--- assembly_info.txt ---"
cat "${OUTDIR}/assembly_info.txt" 2>/dev/null || echo "(assembly_info.txt not found)"
