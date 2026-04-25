#!/usr/bin/env bash
#SBATCH -A silage_microbiome
#SBATCH -N 1
#SBATCH -n 20
#SBATCH --mem=40G
#SBATCH -p ceres
#SBATCH -t 6:00:00
#SBATCH --job-name=sort_eg_mask
#SBATCH --array=1-9
#SBATCH --output=/dev/null

set -euo pipefail

# Resolve project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="/project/silage_microbiome/max.chi/fusarium_sequencing"

# Load paths and tools
source "${PROJECT_ROOT}/config/paths.sh"
module load funannotate
export AUGUSTUS_CONFIG_PATH="${DB_ROOT}/augustus_config/config"


# Pick this task's sample from manifest
MANIFEST="${BATCH_DIR}/batch1_manifest.tsv"
LINE_NUM=$((SLURM_ARRAY_TASK_ID + 1))
IFS=$'\t' read -r barcode sample_id assembly_file busco_name earlgrey_species funannotate_name \
    < <(sed -n "${LINE_NUM}p" "$MANIFEST")

# Per-sample log
mkdir -p "${LOG_DIR}/sort_earlgrey_mask"
log_file="${LOG_DIR}/sort_earlgrey_mask/${sample_id}.log"
exec >"${log_file}" 2>&1

echo "[$(date)] Starting: ${sample_id} (task ${SLURM_ARRAY_TASK_ID})"

# Derive paths
ASSEMBLY="${POLISHED_DIR}/${assembly_file}"
SORTED="${POLISHED_DIR}/${sample_id}_sort.fa"
FAMILIES_FA="${EARLGREY_DIR}/${earlgrey_species}_EarlGrey/${earlgrey_species}_Database/${earlgrey_species}-families.fa"
MASKED="${MASK_DIR}/${sample_id}_masked.fa"

mkdir -p "${EARLGREY_DIR}" "${MASK_DIR}"

##############################
# 1) funannotate sort
##############################
echo "[$(date)] STEP 1: funannotate sort"

if [[ ! -s "${SORTED}" ]]; then
    funannotate sort \
        -i "${ASSEMBLY}" \
        --minlen 1000 \
        -o "${SORTED}"
else
    echo "  Skipping — output exists: ${SORTED}"
fi

##############################
# 2) EarlGrey
##############################
echo "[$(date)] STEP 2: EarlGrey"

if [[ ! -s "${FAMILIES_FA}" ]]; then
    apptainer run \
        --bind "${POLISHED_DIR}:${POLISHED_DIR}" \
        --bind "${EARLGREY_DIR}:${EARLGREY_DIR}" \
        "${EARLGREY_SIF}" \
        earlGrey \
            -g "${SORTED}" \
            -s "${earlgrey_species}" \
            -t "${SLURM_NTASKS}" \
            -o "${EARLGREY_DIR}"

    if [[ ! -s "${FAMILIES_FA}" ]]; then
        echo "ERROR: families.fa not found after EarlGrey: ${FAMILIES_FA}" >&2
        find "${EARLGREY_DIR}" -name "*families.fa" >&2 || true
        exit 1
    fi
else
    echo "  Skipping — output exists: ${FAMILIES_FA}"
fi

##############################
# 3) funannotate mask
# -m repeatmasker + -l because EarlGrey already ran
# RepeatModeler internally — no need to run it again.
##############################
echo "[$(date)] STEP 3: funannotate mask"
cd "${MASK_DIR}"

if [[ ! -s "${MASKED}" ]]; then
    funannotate mask \
        -i "${SORTED}" \
        -m repeatmasker \
        -l "${FAMILIES_FA}" \
        -o "${MASKED}" \
        --cpus "${SLURM_NTASKS}"
else
    echo "  Skipping — output exists: ${MASKED}"
fi

echo "[$(date)] Done: ${sample_id} → ${MASKED}"
