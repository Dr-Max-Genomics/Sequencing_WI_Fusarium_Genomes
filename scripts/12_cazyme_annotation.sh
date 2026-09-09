#!/usr/bin/env bash
#SBATCH -A silage_microbiome
#SBATCH -N 1
#SBATCH -n 32
#SBATCH --mem=120G
#SBATCH -p ceres
#SBATCH -t 06:00:00
#SBATCH --job-name=13a_cazyme_dbcan
#SBATCH --array=1-7
#SBATCH --output=/dev/null

set -euo pipefail

###############################################################################
# 13a_cazyme_dbcan.sh
# Purpose : Run dbCAN (HMMER + DIAMOND) on one annotated proteome per array task.
# Input   : ${FUN_PREDICT_DIR}/${funannotate_name}/annotate_results/*.proteins.fa
# Output  : ${PROJECT_ROOT}/13a_CAzymes/<sample>/ (dbCAN outputs + per-sample log)
###############################################################################

# -------------------------------
# Load batch configuration
# -------------------------------
PROJECT_ROOT="${PROJECT_ROOT:-/project/silage_microbiome/max.chi/fusarium_sequencing}"

# Source your config file
if [[ -f "${PROJECT_ROOT}/config/paths.sh" ]]; then
    # shellcheck disable=SC1091
    source "${PROJECT_ROOT}/config/paths.sh"
else
    echo "ERROR: Cannot find ${PROJECT_ROOT}/config/paths.sh" >&2
    exit 1
fi

# MANIFEST is defined inside paths.sh:
#   MANIFEST="${PROJECT_ROOT}/config/manifests/${BATCH_ID}_manifest.tsv"

FUN_PREDICT_DIR="${FUN_PREDICT_DIR}"   # from config
ANN_BASE="${FUN_PREDICT_DIR}"          # root of funannotate predict results

# dbCAN local DB (from your configuration)
DBCAN_DB_ROOT="${DB_ROOT}/dbCAN_v4_local"

CPUS="${SLURM_NTASKS}"

export APPTAINER_BINDPATH="${DBCAN_DB_ROOT},${PROJECT_ROOT}"
export APPTAINER_TMPDIR="${TMPDIR:-/tmp}"
export SINGULARITY_TMPDIR="${APPTAINER_TMPDIR}"

module load run_dbcan/4.1.1

# -------------------------------
# Read sample metadata from manifest
# -------------------------------
LINE_NUM=$((SLURM_ARRAY_TASK_ID + 1))

IFS=$'\t' read -r barcode sample_id assembly_file busco_name earlgrey_species \
                funannotate_name funannotate_species protein_evidence_file antismash_file \
    < <(sed -n "${LINE_NUM}p" "${MANIFEST}")

if [[ -z "${sample_id}" ]]; then
    echo "ERROR: No sample at manifest line ${LINE_NUM}" >&2
    exit 1
fi

SAMPLE="${sample_id}"
SPECIES="${funannotate_species}"
ISOLATE="${funannotate_name}"

# -------------------------------
# Resolve annotate_results directory
# -------------------------------
ANNOTATE_DIR="${ANN_BASE}/${funannotate_name}/annotate_results"

if [[ ! -d "${ANNOTATE_DIR}" ]]; then
    echo "ERROR: annotate_results directory missing: ${ANNOTATE_DIR}" >&2
    exit 1
fi

# -------------------------------
# Find proteins.fa (glob, generic, safe)
# -------------------------------
PROTEINS_FAA="$(find "${ANNOTATE_DIR}" -maxdepth 1 -type f -name "*.proteins.fa" -print -quit || true)"

if [[ -z "${PROTEINS_FAA}" ]]; then
    echo "ERROR: No *.proteins.fa found for ${SAMPLE} in ${ANNOTATE_DIR}" >&2
    exit 1
fi

if [[ ! -s "${PROTEINS_FAA}" ]]; then
    echo "ERROR: proteins.fa found but empty: ${PROTEINS_FAA}" >&2
    exit 1
fi

# -------------------------------
# Output layout
# -------------------------------
OUT_DIR="${CAZYMES_DIR}/${SAMPLE}"
LOG_FILE="${LOG_DIR}/cazymes/${SAMPLE}.log"

mkdir -p "${OUT_DIR}" "${LOG_DIR}/cazymes"
exec >"${LOG_FILE}" 2>&1

echo ""
echo "[$(date)] dbCAN v4.1.1 CAZyme annotation"
echo "Sample:      ${SAMPLE}"
echo "Species:     ${SPECIES}"
echo "Isolate:     ${ISOLATE}"
echo "FunAnn dir:  ${funannotate_name}"
echo "Proteins FA: ${PROTEINS_FAA}"
echo "Output dir:  ${OUT_DIR}"
echo "Threads:     ${CPUS}"
echo "Job ID:      ${SLURM_JOB_ID:-NA} / task ${SLURM_ARRAY_TASK_ID:-NA}"
echo "Host:        $(hostname)"
echo ""

# -------------------------------
# Pre-flight DB checks
# -------------------------------
fail=false
[[ -d "${DBCAN_DB_ROOT}" ]] || { echo "ERROR: DB dir not found: ${DBCAN_DB_ROOT}"; fail=true; }

[[ -s "${DBCAN_DB_ROOT}/dbCAN_sub.hmm" ]] || { echo "ERROR: missing dbCAN_sub.hmm"; fail=true; }
[[ -s "${DBCAN_DB_ROOT}/CAZy.dmnd" ]] || { echo "ERROR: missing CAZy.dmnd"; fail=true; }

if [[ "${fail}" == "true" ]]; then
    echo "Aborting due to DB validation failures."
    exit 1
fi

# -------------------------------
# Run dbCAN
# -------------------------------
echo "[$(date)] Running dbCAN..."
(
    cd "${OUT_DIR}"
    run_dbcan "${PROTEINS_FAA}" protein \
        --out_dir "${OUT_DIR}" \
        --db_dir "${DBCAN_DB_ROOT}" \
        --dbCANFile "${DBCAN_DB_ROOT}/dbCAN-HMMdb-V14.txt" \
        --tools hmmer diamond \
        --hmm_cpu "${CPUS}" \
        --dia_cpu "${CPUS}" \
        --hmm_eval 1e-3 \
        --dia_eval 1e-5 \
        > "${OUT_DIR}/dbcan.stdout" 2> "${OUT_DIR}/dbcan.stderr" || true
)

# -------------------------------
# Check for overview file
# -------------------------------
find_overview() {
    local d="$1"
    for f in overview.txt overview_result.txt overview.tsv; do
        [[ -f "${d}/${f}" ]] && { echo "${d}/${f}"; return 0; }
    done
    echo ""
}

OVERVIEW="$(find_overview "${OUT_DIR}")"

if [[ -n "${OVERVIEW}" ]]; then
    echo "Overview file detected: ${OVERVIEW}"
else
    echo "WARNING: No overview file found. Check hmmer.out/diamond.out."
fi

echo ""
echo "[$(date)] Done for ${SAMPLE}"