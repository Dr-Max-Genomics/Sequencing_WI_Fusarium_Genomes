#!/usr/bin/env bash
#SBATCH -A silage_microbiome
#SBATCH -N 1
#SBATCH -n 20
#SBATCH --mem=40G
#SBATCH -p ceres
#SBATCH -t 6:00:00
#SBATCH --job-name=sort_eg_mask_unpolished
#SBATCH --array=1-7
#SBATCH --output=/dev/null

set -euo pipefail

PROJECT_ROOT="/project/silage_microbiome/max.chi/fusarium_sequencing"
source "${PROJECT_ROOT}/config/paths.sh"

module load funannotate
export AUGUSTUS_CONFIG_PATH="${DB_ROOT}/augustus_config/config"

# -----------------------------------------------------------------------
# Read manifest (only sample_id matters now)
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
# Unpolished assembly path
# -----------------------------------------------------------------------
UNPOLISHED_DIR="/90daydata/silage_microbiome/max_seq/batch3_2026-May/05_Genome_Assembly"
ASSEMBLY="${UNPOLISHED_DIR}/${sample_id}_flye/assembly.fasta"

if [[ ! -s "${ASSEMBLY}" ]]; then
    echo "ERROR: unpolished assembly not found: ${ASSEMBLY}" >&2
    exit 1
fi

# -----------------------------------------------------------------------
# Output directories (unpolished versions)
# -----------------------------------------------------------------------
SORT_DIR="${POLISHED_DIR}_unpolished"
EG_DIR="${EARLGREY_DIR}_unpolished"
MASK_DIR_UNPOL="${MASK_DIR}_unpolished"

mkdir -p "${SORT_DIR}" "${EG_DIR}" "${MASK_DIR_UNPOL}"

# -----------------------------------------------------------------------
# Output filenames (with _unpolished suffix)
# -----------------------------------------------------------------------
SORTED="${SORT_DIR}/${sample_id}_sorted_unpolished.fa"
MASKED="${MASK_DIR_UNPOL}/${sample_id}_masked_unpolished.fa"

# -----------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------
mkdir -p "${LOG_DIR}/sort_earlgrey_mask_unpolished"
log_file="${LOG_DIR}/sort_earlgrey_mask_unpolished/${sample_id}_unpolished.log"
exec >"${log_file}" 2>&1

echo "[$(date)] Starting unpolished EarlGrey + mask for ${sample_id}"
echo "Assembly: ${ASSEMBLY}"
echo "Sorted:   ${SORTED}"
echo "Masked:   ${MASKED}"

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
    echo "  Skipping — exists: ${SORTED}"
fi

##############################
# 2) EarlGrey
##############################
echo "[$(date)] STEP 2: EarlGrey"

EG_SAMPLE_DIR="${EG_DIR}/${sample_id}_EarlGrey"

if [[ ! -d "${EG_SAMPLE_DIR}" ]]; then
    apptainer run \
        --bind "${SORT_DIR}:${SORT_DIR}" \
        --bind "${EG_DIR}:${EG_DIR}" \
        "${EARLGREY_SIF}" \
        earlGrey \
            -g "${SORTED}" \
            -s "${sample_id}" \
            -t "${SLURM_NTASKS}" \
            -o "${EG_DIR}"
else
    echo "  Skipping — EarlGgrey output exists: ${EG_SAMPLE_DIR}"
fi

##############################
# Locate families.fa.strained (robust across EarlGrey versions)
##############################
echo "[$(date)] Locating families.fa.strained"

FAMILIES_FA=$(find "${EG_SAMPLE_DIR}" \
    -maxdepth 6 \
    -type f \
    -name "${sample_id}-families.fa.strained" \
    2>/dev/null | head -n 1 || true)

if [[ -z "${FAMILIES_FA}" ]]; then
    echo "ERROR: Could not locate families.fa.strained under ${EG_SAMPLE_DIR}" >&2
    echo "Directory contents:"
    find "${EG_SAMPLE_DIR}" -maxdepth 6 -name "*families.fa*" 2>/dev/null || true
    exit 1
fi

echo "Found families file:"
echo "  ${FAMILIES_FA}"

##############################
# 3) funannotate mask
##############################
echo "[$(date)] STEP 3: funannotate mask"
cd "${MASK_DIR_UNPOL}"

if [[ ! -s "${MASKED}" ]]; then
    funannotate mask \
        -i "${SORTED}" \
        -m repeatmasker \
        -l "${FAMILIES_FA}" \
        -o "${MASKED}" \
        --cpus "${SLURM_NTASKS}"
else
    echo "  Skipping — exists: ${MASKED}"
fi

echo "[$(date)] Done: ${sample_id} → ${MASKED}"
