#!/usr/bin/env bash
#SBATCH -A silage_microbiome
#SBATCH -N 1
#SBATCH -n 32
#SBATCH --mem=100G
#SBATCH -p ceres
#SBATCH -t 6:00:00
#SBATCH --job-name=effectorome
#SBATCH --array=1-9
#SBATCH --output=/dev/null

set -euo pipefail

# =======================================================================
# 12_effectorome.sh
# Purpose : Predict the secretome and effectorome in three steps:
#           1. SignalP6   — predict signal peptides (all proteins → secretome)
#           2. Extract    — pull SP-positive proteins into secretome FASTA
#           3. EffectorP  — classify secretome as cytoplasmic/apoplastic effectors
#
# Input   : annotate_results/*_new.proteins.fa (funannotate annotate output)
# Output  : 13_Effectorome/{sample_id}/
#             signalp/              → SignalP6 output directory
#             {sample_id}_secretome.fasta        → SP-positive proteins
#             {sample_id}_predict_effectors.fasta → EffectorP effector hits
#             {sample_id}_effector_summary.txt    → EffectorP full summary
#
# Usage   : sbatch --array=1 scripts/12_effectorome.sh     # test one
#           sbatch --array=2-9 scripts/12_effectorome.sh   # rest of batch
# -----------------------------------------------------------------------
# NOTE on SignalP6 model_dir:
#   If signalp6 fails with model not found, locate the model weights:
#     python3 -c "import signalp, os; print(os.path.dirname(signalp.__file__))"
#   Then set MODEL_DIR below to <that_path>/model_weights/
#   Leave MODEL_DIR="" to use the default installation (preferred).
# -----------------------------------------------------------------------
# NOTE on EffectorP:
#   EffectorP.py requires functions.py and weka-3-8-4/ in the same
#   directory. These live in ${SCRIPTS_DIR}. The FUNGAL_MODE (-F flag)
#   is used since all isolates are Fusarium spp.
# =======================================================================

PROJECT_ROOT="${PROJECT_ROOT:-/project/silage_microbiome/max.chi/fusarium_sequencing}"
source "${PROJECT_ROOT}/config/paths.sh"

# -----------------------------------------------------------------------
# Configurable paths  (edit if locations differ)
# -----------------------------------------------------------------------
EFFECTOROME_DIR="${BATCH_DIR}/13_Effectorome"
EFFECTORP_SCRIPT="${SCRIPTS_DIR}/EffectorP.py"

# SignalP6 model directory — leave empty to use default installation path
MODEL_DIR=""

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
ANNOTATE_DIR="${FUN_PREDICT_DIR}/${funannotate_name}/annotate_results"
INPUT_PROTEINS=$(find "${ANNOTATE_DIR}" -maxdepth 1 -name "*_new.proteins.fa" | head -1)

SAMPLE_DIR="${EFFECTOROME_DIR}/${sample_id}"
SIGNALP_DIR="${SAMPLE_DIR}/signalp"
SECRETOME_FA="${SAMPLE_DIR}/${sample_id}_secretome.fasta"
EFFECTORS_FA="${SAMPLE_DIR}/${sample_id}_predict_effectors.fasta"
EFFECTOR_SUMMARY="${SAMPLE_DIR}/${sample_id}_effector_summary.txt"

mkdir -p "${SAMPLE_DIR}" "${SIGNALP_DIR}" "${LOG_DIR}/effectorome"
log_file="${LOG_DIR}/effectorome/${sample_id}.log"
exec >"${log_file}" 2>&1

echo "=========================================="
echo "[$(date)] Effectorome pipeline"
echo "Sample:          ${sample_id}"
echo "Input proteins:  ${INPUT_PROTEINS:-NOT FOUND}"
echo "SignalP dir:     ${SIGNALP_DIR}"
echo "Secretome:       ${SECRETOME_FA}"
echo "Effectors:       ${EFFECTORS_FA}"
echo "Summary:         ${EFFECTOR_SUMMARY}"
echo "Manifest:        ${MANIFEST}"
echo "Job ID:          ${SLURM_JOB_ID} / task ${SLURM_ARRAY_TASK_ID}"
echo "Host:            $(hostname)"
echo "=========================================="

# Validate inputs
if [[ -z "${INPUT_PROTEINS}" || ! -s "${INPUT_PROTEINS}" ]]; then
    echo "ERROR: no *_new.proteins.fa in ${ANNOTATE_DIR}" >&2
    ls "${ANNOTATE_DIR}" >&2 || true
    echo "Did 09c_FUN_annotate.sh complete for ${sample_id}?" >&2
    exit 1
fi

if [[ ! -f "${EFFECTORP_SCRIPT}" ]]; then
    echo "ERROR: EffectorP.py not found at ${EFFECTORP_SCRIPT}" >&2
    exit 1
fi

protein_count=$(grep -c "^>" "${INPUT_PROTEINS}")
echo "Input protein count: ${protein_count}"

# -----------------------------------------------------------------------
# Activate conda env (mycotools has SignalP6 + its dependencies)
# -----------------------------------------------------------------------
module load miniconda
source activate mycotools
# Robust fallback (uncomment if above fails on batch node):
# source "$(conda info --base)/etc/profile.d/conda.sh"
# conda activate mycotools

# -----------------------------------------------------------------------
# STEP 1 — SignalP6: predict signal peptides on all proteins
# -----------------------------------------------------------------------
if compgen -G "${SIGNALP_DIR}/prediction_results.txt" > /dev/null; then
    echo "[$(date)] SignalP6 output exists — skipping step 1"
else
    echo "[$(date)] STEP 1: Running SignalP6 (fast mode, eukarya)..."
    echo "Input: ${INPUT_PROTEINS} (${protein_count} proteins)"

    # Build model_dir flag if set
    MODEL_FLAG=""
    if [[ -n "${MODEL_DIR}" ]]; then
        MODEL_FLAG="--model_dir ${MODEL_DIR}"
    fi

    # shellcheck disable=SC2086
    signalp6 \
        --fastafile "${INPUT_PROTEINS}" \
        --organism eukarya \
        --output_dir "${SIGNALP_DIR}" \
        --format txt \
        --mode fast \
        --torch_num_threads "${SLURM_NTASKS}" \
        --write_procs "${SLURM_NTASKS}" \
        ${MODEL_FLAG}

    echo "[$(date)] SignalP6 complete."
fi

# Validate SignalP6 output
SP_SUMMARY="${SIGNALP_DIR}/prediction_results.txt"
if [[ ! -s "${SP_SUMMARY}" ]]; then
    echo "ERROR: SignalP6 prediction_results.txt missing or empty: ${SP_SUMMARY}" >&2
    ls "${SIGNALP_DIR}" >&2 || true
    exit 1
fi

# -----------------------------------------------------------------------
# STEP 2 — Extract secretome: pull SP-positive proteins into a FASTA
# SignalP6 prediction_results.txt format (tab-separated):
#   ID  Prediction  SP(Sec/SPI)  TAT(Tat/SPI)  ... CS Position
# Proteins with Prediction == "SP" have a signal peptide.
# -----------------------------------------------------------------------
if [[ -s "${SECRETOME_FA}" ]]; then
    echo "[$(date)] Secretome FASTA exists — skipping step 2"
else
    echo "[$(date)] STEP 2: Extracting SP-positive proteins (secretome)..."

    # Extract IDs with SP prediction
    SP_IDS="${SAMPLE_DIR}/${sample_id}_sp_ids.txt"
    awk 'NR>1 && $2 == "SP" {print $1}' "${SP_SUMMARY}" > "${SP_IDS}"
    sp_count=$(wc -l < "${SP_IDS}")
    echo "Signal peptide-positive proteins: ${sp_count} / ${protein_count}"

    if [[ "${sp_count}" -eq 0 ]]; then
        echo "WARN: no signal peptide-positive proteins found in ${SP_SUMMARY}" >&2
        echo "Check SignalP6 output format — column 2 should be 'SP' for positives." >&2
        touch "${SECRETOME_FA}"
    else
        # Extract sequences matching SP IDs (handles SignalP6 _ substitution)
        export SP_IDS INPUT_PROTEINS SECRETOME_FA
        python3 - <<'PYEOF'
import os

sp_ids_file = os.environ['SP_IDS']
proteins_file = os.environ['INPUT_PROTEINS']
secretome_file = os.environ['SECRETOME_FA']

sp_ids = set()
with open(sp_ids_file) as f:
    for line in f:
        sp_ids.add(line.strip())

written = 0
write_seq = False
with open(proteins_file) as fin, open(secretome_file, 'w') as fout:
    for line in fin:
        if line.startswith('>'):
            raw_id = line[1:].split()[0]
            # SignalP6 replaces non-alphanumeric chars with '_' in IDs
            clean_id = ''.join(c if c.isalnum() or c in '._-' else '_' for c in raw_id)
            write_seq = (raw_id in sp_ids or clean_id in sp_ids)
            if write_seq:
                fout.write(line)
                written += 1
        elif write_seq:
            fout.write(line)

print(f"Secretome FASTA written: {written} proteins")
PYEOF
    fi
    echo "[$(date)] Secretome extraction complete."
fi

secretome_count=$(grep -c "^>" "${SECRETOME_FA}" 2>/dev/null || echo 0)
echo "Secretome size: ${secretome_count} proteins"

if [[ "${secretome_count}" -eq 0 ]]; then
    echo "WARN: secretome is empty — skipping EffectorP" >&2
    touch "${EFFECTORS_FA}" "${EFFECTOR_SUMMARY}"
    exit 0
fi

# -----------------------------------------------------------------------
# STEP 3 — EffectorP: classify secretome as effectors / non-effectors
# -F flag = fungal mode (appropriate for Fusarium spp.)
# -i = input secretome FASTA
# -E = output predicted effectors FASTA
# -o = output summary TSV
# -----------------------------------------------------------------------
if [[ -s "${EFFECTOR_SUMMARY}" ]]; then
    echo "[$(date)] EffectorP summary exists — skipping step 3"
else
    echo "[$(date)] STEP 3: Running EffectorP (fungal mode)..."
    echo "Input: ${SECRETOME_FA} (${secretome_count} secreted proteins)"

    # EffectorP needs to be run from its own directory (for functions.py import)
    cd "${SCRIPTS_DIR}"

    python3 "${EFFECTORP_SCRIPT}" \
        -i "${SECRETOME_FA}" \
        -F \
        -E "${EFFECTORS_FA}" \
        -o "${EFFECTOR_SUMMARY}"

    echo "[$(date)] EffectorP complete."
fi

# -----------------------------------------------------------------------
# Summary report
# -----------------------------------------------------------------------
echo
echo "=========================================="
echo "[$(date)] Effectorome summary: ${sample_id}"
echo "=========================================="
echo "Total proteins:        ${protein_count}"
echo "Secretome (SP+):       ${secretome_count}"

if [[ -s "${EFFECTOR_SUMMARY}" ]]; then
    echo
    echo "--- EffectorP results ---"
    tail -20 "${EFFECTOR_SUMMARY}"
fi

if [[ -s "${EFFECTORS_FA}" ]]; then
    effector_count=$(grep -c "^>" "${EFFECTORS_FA}" 2>/dev/null || echo 0)
    echo
    echo "Predicted effectors:   ${effector_count}"
fi

echo
echo "[$(date)] Done: ${sample_id}"
echo "Output directory: ${SAMPLE_DIR}"
