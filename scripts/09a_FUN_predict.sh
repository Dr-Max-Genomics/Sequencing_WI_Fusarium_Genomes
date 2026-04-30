#!/usr/bin/env bash
#SBATCH -A silage_microbiome
#SBATCH -N 1
#SBATCH -n 20
#SBATCH --mem=80G
#SBATCH -p ceres
#SBATCH -t 1-0
#SBATCH --job-name=fun_predict
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
export APPTAINERENV_FUNANNOTATE_DB="${DB_ROOT}/funannotate_db"


# Pick this task's sample from manifest
MANIFEST="${BATCH_DIR}/batch1_manifest.tsv"
LINE_NUM=$((SLURM_ARRAY_TASK_ID + 1))

IFS=$'\t' read -r \
    barcode sample_id assembly_file busco_name earlgrey_species \
    funannotate_name funannotate_species protein_evidence_file antismash_file \
    < <(sed -n "${LINE_NUM}p" "$MANIFEST")

#Pick busco _seed species based on actual species
case "$funannotate_species" in
    "Fusarium graminearum"|"Fusarium cerealis")
        BUSCO_SEED="fusarium_graminearum"
        ;;
    "Fusarium "*)
        BUSCO_SEED="fusarium"
        ;;
    *)
        BUSCO_SEED="fusarium"  #fallback
        ;;
esac


# Per-sample log
mkdir -p "${LOG_DIR}/fun_predict"
log_file="${LOG_DIR}/fun_predict/${sample_id}.log"
exec >"${log_file}" 2>&1

echo "[$(date)] Starting predict: ${sample_id} (task ${SLURM_ARRAY_TASK_ID})"
echo "  Species:           ${funannotate_species}"
echo "  Strain:            ${sample_id}"
echo "  Protein evidence:  ${protein_evidence_file}"

# Derive paths
MASKED="${MASK_DIR}/${sample_id}_masked.fa"
OUTPUT_DIR="${FUN_PREDICT_DIR}/${funannotate_name}"
PROTEIN_EVIDENCE="${PROTEIN_EVIDENCE_DIR}/${protein_evidence_file}"
AUGUSTUS_NAME="${sample_id}"

# Validate inputs
[[ -s "${MASKED}" ]]            || { echo "ERROR: masked genome missing: ${MASKED}" >&2; exit 1; }
[[ -s "${PROTEIN_EVIDENCE}" ]]  || { echo "ERROR: protein evidence missing: ${PROTEIN_EVIDENCE}" >&2; exit 1; }

mkdir -p "${FUN_PREDICT_DIR}"

##############################
# funannotate predict
##############################
echo "[$(date)] Running funannotate predict"

if [[ ! -s "${OUTPUT_DIR}/predict_results/${funannotate_species// /_}_${sample_id}.gff3" ]]; then
    funannotate predict \
        -i "${MASKED}" \
        -o "${OUTPUT_DIR}" \
        --species "${funannotate_species}" \
        --strain "${sample_id}" \
        --augustus_species "${AUGUSTUS_NAME}" \
        --busco_seed_species "${BUSCO_SEED}" \
        --busco_db hypocreales \
        --protein_evidence "${PROTEIN_EVIDENCE}" \
        --optimize_augustus \
        --tbl2asn "-l paired-ends" \
        --cpus "${SLURM_NTASKS}"
else
    echo "  Skipping — output exists: ${OUTPUT_DIR}/predict_results/"
fi

echo "[$(date)] Done: ${sample_id} → ${OUTPUT_DIR}/predict_results/"
