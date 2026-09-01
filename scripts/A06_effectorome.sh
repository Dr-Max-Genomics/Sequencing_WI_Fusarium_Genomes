#!/bin/bash -l
#SBATCH --job-name=effectorome
#SBATCH -A silage_microbiome
#SBATCH -p gpu-a100
#SBATCH --gres=gpu:a100:1
#SBATCH --qos=normal
#SBATCH -N 1
#SBATCH -n 8
#SBATCH -t 02:00:00
#SBATCH --mem=128G
#SBATCH --array=1-7
#SBATCH --mail-user=maxwell.chibuogwu@usda.gov
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --output=/dev/null
#SBATCH --error=/dev/null

set -euo pipefail

# -----------------------------------------------------------------------
# CONFIGURATION
# -----------------------------------------------------------------------
PROJECT_ROOT="/90daydata/silage_microbiome/Max_Fus_Batch3"

INPUT_DIR="${PROJECT_ROOT}/fun_annotate_effectorome_input"
OUTPUT_DIR="${PROJECT_ROOT}/Effectorome_results"
SCRIPTS_DIR="${PROJECT_ROOT}/Scripts"

EFFECTORP_DIR="${PROJECT_ROOT}/effectorP3c"
EFFECTORP="${EFFECTORP_DIR}/EffectorP.py"
WEKA_JAR="${EFFECTORP_DIR}/weka-3-8-4/weka.jar"
FUNCTIONS_PY="${EFFECTORP_DIR}/functions.py"

mkdir -p "${OUTPUT_DIR}"

# ----------------------------
# INLINE SAMPLE LIST
# ----------------------------
SAMPLES=("" "Fus_Bar01" "Fus_Bar02" "Fus_Bar04" "Fus_Bar05" "Fus_Bar06" "Fus_Bar07" "Fus_Bar08")
sample_id="${SAMPLES[$SLURM_ARRAY_TASK_ID]:-}"
[[ -z "${sample_id}" ]] && { echo "ERROR: No sample for task $SLURM_ARRAY_TASK_ID"; exit 1; }

# Input lookup
shopt -s nullglob
matches=( "${INPUT_DIR}"/*_"${sample_id}".proteins.fa )
shopt -u nullglob
[[ ${#matches[@]} -eq 0 ]] && { echo "ERROR: No proteins FASTA for ${sample_id}"; exit 1; }
INPUT_PROTEINS="${matches[0]}"

# Outputs
SAMPLE_DIR="${OUTPUT_DIR}/${sample_id}"
SIGNALP_DIR="${SAMPLE_DIR}/signalp"
SECRETOME_FA="${SAMPLE_DIR}/${sample_id}_secretome.fasta"
EFFECTORS_FA="${SAMPLE_DIR}/${sample_id}_predict_effectors.fasta"
EFFECTOR_SUMMARY="${SAMPLE_DIR}/${sample_id}_effector_summary.txt"
mkdir -p "${SAMPLE_DIR}" "${SIGNALP_DIR}"

# Logging
LOG_DIR="${PROJECT_ROOT}/logs/effectorome"
mkdir -p "${LOG_DIR}"
exec > "${LOG_DIR}/${sample_id}.log" 2>&1

echo "=========================================="
echo "[$(date)] Effectorome pipeline START"
echo "Sample:        ${sample_id}"
echo "Input FASTA:   ${INPUT_PROTEINS}"
echo "Node:          $(hostname)"
echo "Partition:     ${SLURM_JOB_PARTITION:-unknown}"
echo "CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-unset}"
echo "=========================================="

# Validate
[[ ! -s "${INPUT_PROTEINS}" ]] && { echo "ERROR: Missing FASTA ${INPUT_PROTEINS}"; exit 1; }
protein_count=$(grep -c "^>" "${INPUT_PROTEINS}")
echo "Protein count: ${protein_count}"

# ----------------------------
# Conda + clean environment
# ----------------------------
module purge
module load miniconda3
source activate mycotools
export OMP_NUM_THREADS=1

echo "Activated Conda env: $(which python)"

# ----------------------------
# GPU sanity checks (fail-fast)
# ----------------------------
echo "nvidia-smi:"
if ! nvidia-smi; then
  echo "ERROR: No NVIDIA driver/GPU visible on this node."; exit 1;
fi

python - <<'PY'
import torch, sys
print("PyTorch CUDA version:", torch.version.cuda)
print("CUDA available?     :", torch.cuda.is_available())
print("CUDA device count   :", torch.cuda.device_count())
if torch.cuda.is_available() and torch.cuda.device_count() > 0:
    print("GPU 0:", torch.cuda.get_device_name(0))
else:
    sys.exit("ERROR: torch.cuda.is_available() == False")
PY

# ----------------------------
# STEP 1 — SignalP6 (GPU via srun)
# ----------------------------
SP_SUMMARY="${SIGNALP_DIR}/prediction_results.txt"

if [[ ! -s "${SP_SUMMARY}" ]]; then
  echo "[$(date)] Running SignalP6 on GPU via srun..."

  export SIGNALP_USE_GPU=1

  srun -n 1 --cpu-bind=none \
    signalp6 \
      --fastafile "${INPUT_PROTEINS}" \
      --organism eukarya \
      --output_dir "${SIGNALP_DIR}" \
      --format txt \
      --mode fast \
      --bsize 256 \
      --torch_num_threads 1 \
      --model_dir "${PROJECT_ROOT}/signalp6_fast/signalp-6-package/models"

  echo "[$(date)] SignalP6 complete."
else
  echo "[$(date)] SignalP6 output detected — skipping."
fi

[[ ! -s "${SP_SUMMARY}" ]] && { echo "ERROR: SignalP6 produced no prediction_results.txt"; exit 1; }

# ----------------------------
# STEP 2 — Extract secretome
# ----------------------------
echo "[$(date)] Extracting secretome..."

SP_IDS="${SAMPLE_DIR}/sp_ids.txt"
awk 'NR>1 && $3=="SP"{print $1}' "${SP_SUMMARY}" > "${SP_IDS}"

python3 <<EOF
ids = set(x.strip() for x in open("${SP_IDS}"))
with open("${INPUT_PROTEINS}") as fin, open("${SECRETOME_FA}", "w") as fout:
    keep = False
    for line in fin:
        if line.startswith(">"):
            pid = line[1:].split()[0]
            keep = pid in ids
        if keep:
            fout.write(line)
EOF

secretome_count=$(grep -c "^>" "${SECRETOME_FA}" 2>/dev/null || echo 0)
secretome_count="${secretome_count//[^0-9]/}"   # strip any non-numeric junk

echo "Secretome size: ${secretome_count}"

if [ "${secretome_count}" -eq 0 ]; then
  echo "WARN: No secreted proteins; skipping EffectorP."
  : > "${EFFECTORS_FA}"; : > "${EFFECTOR_SUMMARY}"
  exit 0
fi
# ----------------------------
# STEP 3 — EffectorP3c (CPU)
# ----------------------------
echo "[$(date)] Running EffectorP..."

python3 "${EFFECTORP}" \
  -i "${SECRETOME_FA}" \
  -f \
  -E "${EFFECTORS_FA}" \
  -o "${EFFECTOR_SUMMARY}" 

echo "[$(date)] EffectorP complete."
echo "=========================================="
echo "[$(date)] Finished sample: ${sample_id}"
echo "Output directory: ${SAMPLE_DIR}"
echo "=========================================="
