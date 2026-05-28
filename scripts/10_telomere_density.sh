#!/usr/bin/env bash
#SBATCH -A silage_microbiome
#SBATCH -N 1
#SBATCH -n 4
#SBATCH --mem=16G
#SBATCH -p ceres
#SBATCH -t 2:00:00
#SBATCH --job-name=telomere
#SBATCH --array=1-9
#SBATCH --output=/dev/null

set -euo pipefail

# -----------------------------------------------------------------------
# 10_telomere_search.sh
# Purpose : Run telomere_density.py on each isolate's polished assembly
#           as a SLURM array job.
# Usage   : sbatch --array=1 scripts/10_telomere_search.sh     # test
#           sbatch --array=2-9 scripts/10_telomere_search.sh   # full
# Notes   : Requires Biopython + matplotlib in the activated conda env.
#           Script activates seqenv internally — no need to pre-load.
# -----------------------------------------------------------------------

PROJECT_ROOT="/project/silage_microbiome/max.chi/fusarium_sequencing"
source "${PROJECT_ROOT}/config/paths.sh"

# -----------------------------------------------------------------------
# Environment — activate conda so Biopython and matplotlib are available
# This is the fix for the "cannot import Bio" error on batch nodes.
# -----------------------------------------------------------------------
module load miniconda
# shellcheck disable=SC1091
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate seqenv

# -----------------------------------------------------------------------
# Pick sample from manifest
# -----------------------------------------------------------------------
MANIFEST="${BATCH_DIR}/batch1_manifest.tsv"
LINE_NUM=$((SLURM_ARRAY_TASK_ID + 1))
IFS=$'\t' read -r \
    barcode sample_id assembly_file busco_name earlgrey_species \
    funannotate_name funannotate_species protein_evidence_file antismash_file \
    < <(sed -n "${LINE_NUM}p" "$MANIFEST")

if [[ -z "${sample_id:-}" ]]; then
    echo "ERROR: no sample at manifest line ${LINE_NUM}" >&2
    exit 1
fi

# -----------------------------------------------------------------------
# Paths
# -----------------------------------------------------------------------
ASSEMBLY="${POLISHED_DIR}/${assembly_file}"
TELOMERE_DIR="${BATCH_DIR}/13_Telomere"
SAMPLE_OUTDIR="${TELOMERE_DIR}/${sample_id}"
TSV_OUT="${SAMPLE_OUTDIR}/${sample_id}_telomere_density.tsv"
PLOT_DIR="${SAMPLE_OUTDIR}/plots"
PYTHON_SCRIPT="${PROJECT_ROOT}/scripts/telomere_density.py"

mkdir -p "${LOG_DIR}/telomere" "${SAMPLE_OUTDIR}" "${PLOT_DIR}"

# Per-sample log
log_file="${LOG_DIR}/telomere/${sample_id}.log"
exec >"${log_file}" 2>&1

echo "=========================================="
echo "[$(date)] Telomere density search"
echo "Sample:   ${sample_id}"
echo "Assembly: ${ASSEMBLY}"
echo "Output:   ${TSV_OUT}"
echo "Plots:    ${PLOT_DIR}"
echo "Job ID:   ${SLURM_JOB_ID} / task ${SLURM_ARRAY_TASK_ID}"
echo "Host:     $(hostname)"
echo "=========================================="

# Validate input
if [[ ! -s "${ASSEMBLY}" ]]; then
    echo "ERROR: assembly not found or empty: ${ASSEMBLY}" >&2
    exit 1
fi

if [[ ! -f "${PYTHON_SCRIPT}" ]]; then
    echo "ERROR: telomere_density.py not found at: ${PYTHON_SCRIPT}" >&2
    exit 1
fi

# Skip if already done
if [[ -s "${TSV_OUT}" ]]; then
    echo "TSV already exists and is non-empty — skipping: ${TSV_OUT}"
    exit 0
fi

# -----------------------------------------------------------------------
# Run
# -----------------------------------------------------------------------
echo "[$(date)] Running telomere_density.py"

python "${PYTHON_SCRIPT}" \
    -i  "${ASSEMBLY}" \
    -o  "${TSV_OUT}" \
    --outdir "${PLOT_DIR}" \
    --window 10000 \
    --step   1000 \
    --min-contig 5000

echo "[$(date)] Finished ${sample_id}"
echo "TSV rows: $(wc -l < "${TSV_OUT}")"
echo "Plots:    $(ls "${PLOT_DIR}"/*.png 2>/dev/null | wc -l)"
