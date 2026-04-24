#!/usr/bin/env bash
#SBATCH -A silage_microbiome
#SBATCH -N 1
#SBATCH -n 8
#SBATCH --mem=40G
#SBATCH -p ceres
#SBATCH -t 1:00:00
#SBATCH --job-name=busco_eval
#SBATCH --array=1-9
#SBATCH --output=/dev/null
#SBATCH --error=/dev/null

set -euo pipefail

# -------- resolve paths --------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${PROJECT_ROOT}/config/paths.sh"

# -------- pick this task's sample from the manifest --------
MANIFEST="${BATCH_DIR}/batch1_manifest.tsv"
LINE_NUM=$((SLURM_ARRAY_TASK_ID + 1))   # +1 skips header

IFS=$'\t' read -r barcode sample_id assembly_file busco_name funannotate_name earlgrey_name \
    < <(sed -n "${LINE_NUM}p" "${MANIFEST}")

if [[ -z "${sample_id:-}" ]]; then
    echo "ERROR: no sample at manifest line ${LINE_NUM} of ${MANIFEST}" >&2
    exit 1
fi

# -------- redirect everything to per-sample log --------
mkdir -p "${LOG_DIR}/Busco_eval"
log_file="${LOG_DIR}/Busco_eval/${sample_id}.log"
exec >>"${log_file}" 2>&1

echo "=========================================="
echo "[$(date)] BUSCO evaluation"
echo "Barcode:      ${barcode}"
echo "Sample ID:    ${sample_id}"
echo "Assembly:     ${assembly_file}"
echo "Output name:  ${busco_name}"
echo "Job ID:       ${SLURM_JOB_ID}"
echo "Array task:   ${SLURM_ARRAY_TASK_ID}"
echo "Host:         $(hostname)"
echo "=========================================="

# -------- load modules --------
module load busco5

# -------- locate input assembly --------
ASSEMBLY="${POLISHED_DIR}/${assembly_file}"
if [[ ! -s "${ASSEMBLY}" ]]; then
    echo "ERROR: assembly not found or empty: ${ASSEMBLY}" >&2
    exit 1
fi

# -------- confirm lineage is present --------
LINEAGE="hypocreales_odb10"
LINEAGE_PATH="${BUSCO_DOWNLOADS}/lineages/${LINEAGE}"
if [[ ! -d "${LINEAGE_PATH}" ]]; then
    echo "ERROR: lineage folder missing: ${LINEAGE_PATH}" >&2
    ls -la "${BUSCO_DOWNLOADS}/lineages/" >&2 || true
    exit 1
fi

# -------- run BUSCO --------
mkdir -p "${BUSCO_DIR}"

busco \
    --in "${ASSEMBLY}" \
    --out "${busco_name}" \
    --out_path "${BUSCO_DIR}" \
    --lineage_dataset "${LINEAGE}" \
    --mode genome \
    --cpus 8 \
    --offline \
    --download_path "${BUSCO_DOWNLOADS}" \
    --force

echo "[$(date)] Finished ${sample_id}"
