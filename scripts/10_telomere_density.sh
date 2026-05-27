#!/usr/bin/env bash
#SBATCH -A silage_microbiome
#SBATCH -N 1
#SBATCH -n 4
#SBATCH --mem=16G
#SBATCH -p ceres
#SBATCH -t 2:00:00
#SBATCH --job-name=telomere_density
#SBATCH --array=1-9
#SBATCH --output=/dev/null

set -euo pipefail

# ───────────────────────────────────────────────
# Load project paths
# ───────────────────────────────────────────────
PROJECT_ROOT="/project/silage_microbiome/max.chi/fusarium_sequencing"
source "${PROJECT_ROOT}/config/paths.sh"

# ───────────────────────────────────────────────
# Script + output directories
# ───────────────────────────────────────────────
TEL_SCRIPT="${SCRIPTS_DIR}/telomere_density.py"

OUT_BASE="${BATCH_DIR}/12b_Telomere_Density"
mkdir -p "${OUT_BASE}"

# Log directory (global)
TEL_LOG_DIR="${LOG_DIR}/telomere"
mkdir -p "${TEL_LOG_DIR}"

# ───────────────────────────────────────────────
# Manifest
# ───────────────────────────────────────────────
MANIFEST="${BATCH_DIR}/batch1_manifest.tsv"

LINE_NUM=$((SLURM_ARRAY_TASK_ID + 1))

IFS=$'\t' read -r \
    barcode sample_id assembly_file busco_name funannotate_name \
    < <(sed -n "${LINE_NUM}p" "${MANIFEST}")

FASTA="${POLISHED_DIR}/${assembly_file}"

if [[ ! -s "${FASTA}" ]]; then
    echo "ERROR: FASTA not found: ${FASTA}" >&2
    exit 1
fi

# ───────────────────────────────────────────────
# Per-sample output directory
# ───────────────────────────────────────────────
OUTDIR="${OUT_BASE}/${sample_id}"
mkdir -p "${OUTDIR}"

LOG="${TEL_LOG_DIR}/${sample_id}.log"
exec >"${LOG}" 2>&1

echo "[$(date)] Running telomere density for ${sample_id}"
echo "FASTA: ${FASTA}"
echo "OUTDIR: ${OUTDIR}"

# ───────────────────────────────────────────────
# Load Python environment
# ───────────────────────────────────────────────
module load miniconda
eval "$(conda shell.bash hook)"
source activate mycotools

# ───────────────────────────────────────────────
# Run telomere density script
# ───────────────────────────────────────────────
TSV_OUT="${OUTDIR}/${sample_id}_telomere_density.tsv"

python "${TEL_SCRIPT}" \
    -i "${FASTA}" \
    -o "${TSV_OUT}" \
    --outdir "${OUTDIR}"

echo "[$(date)] Completed telomere density for ${sample_id}"
echo "TSV: ${TSV_OUT}"
echo "PNGs: ${OUTDIR}/*.png"
