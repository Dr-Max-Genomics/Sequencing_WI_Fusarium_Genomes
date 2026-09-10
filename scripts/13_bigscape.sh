#!/usr/bin/env bash
#SBATCH -A silage_microbiome
#SBATCH -N 1
#SBATCH -n 40
#SBATCH --mem=128G
#SBATCH -p ceres
#SBATCH -t 10:00:00
#SBATCH --job-name=14_bigscape
#SBATCH --output=/dev/null

set -euo pipefail

###############################################################################
# Step 14 — BiG-SCAPE clustering of antiSMASH BGCs
#
# Input:
#   - ${ANTISMASH_DIR}/${sample_id}/  (from Step 12a)
#       Contains *.region*.gbk
#
# Output (single directory):
#   - ${BATCH_DIR}/14_BiGSCAPE/
#       bigscape_out/
#       network_files/
#       clustering summaries
#
# Notes:
#   - No 14a/14b split needed.
#   - BiG-SCAPE input = antiSMASH output folders (direct).
#   - Manifest column $6 = funannotate_name controls isolate directories.
###############################################################################

# -------------------------------
# Load project configuration
# -------------------------------
PROJECT_ROOT="${PROJECT_ROOT:-/project/silage_microbiome/max.chi/fusarium_sequencing}"
# shellcheck disable=SC1091
source "${PROJECT_ROOT}/config/paths.sh"

# antiSMASH output root from your existing Step 12a:
#   ANTISMASH_DIR="${BATCH_DIR}/12a_AntiSMASH_gbk"


mkdir -p "${LOG_DIR}/bigscape"

LOG_FILE="${LOG_DIR}/bigscape/14_bigscape_${SLURM_JOB_ID}.log"
exec >"${LOG_FILE}" 2>&1

echo "[$(date)] Step 14 — BiG-SCAPE"
echo "Batch dir       : ${BATCH_DIR}"
echo "Manifest        : ${MANIFEST}"
echo "antiSMASH root  : ${ANTISMASH_DIR}"
echo "BiGSCAPE out    : ${BIGSCAPE_DIR}"
echo ""

# -------------------------------
# Module / environment
# -------------------------------
module load bigscape

PFAM_DIR="${PROJECT_ROOT}/DB_Databases/pfam"

# -------------------------------
# Collect isolates from manifest (column 6 = funannotate_name)
# -------------------------------
mapfile -t isolates < <(
    awk -F'\t' 'NR>1 {print $2}' "${MANIFEST}" | sort -u
)

echo "Isolates detected:"
for iso in "${isolates[@]}"; do
    echo "  - ${iso}"
done
echo ""

echo "[$(date)] Checking antiSMASH region GBK folders..."

valid_input_count=0

# Validate antiSMASH dir per isolate
for iso in "${isolates[@]}"; do
    iso_dir="${ANTISMASH_DIR}/${iso}"

    if [[ ! -d "${iso_dir}" ]]; then
        echo "WARN: antiSMASH directory missing for isolate=${iso} → skipping"
        continue
    fi

    shopt -s nullglob
    region_files=( "${iso_dir}"/*.region*.gbk )
    shopt -u nullglob

    if (( ${#region_files[@]} == 0 )); then
        echo "WARN: No region GBKs found for isolate=${iso} → skipping"
        continue
    fi

    echo "✓ ${iso}: ${#region_files[@]} region GBKs found"
    ((valid_input_count++))
done

if (( valid_input_count == 0 )); then
    echo "ERROR: No antiSMASH region GBKs found for any isolate."
    exit 1
fi

echo ""
echo "[$(date)] Running BiG-SCAPE on antiSMASH output structure..."
echo ""

bigscape \
    --inputdir "${ANTISMASH_DIR}" \
    --outputdir "${BIGSCAPE_DIR}/bigscape_out" \
    --pfam_dir "${PFAM_DIR}" \
    --cores "${SLURM_CPUS_PER_TASK:-40}" \
    --cutoffs 0.30 0.50 0.70 \
    --mibig \
    --mix \
    --hybrids-off \
    --include_singletons

echo ""
echo "[$(date)] BiG-SCAPE clustering complete."

# -------------------------------
# Summaries — GCF statistics
# -------------------------------
echo ""
echo "[$(date)] Summarizing BiG-SCAPE clustering..."

python3 - <<'PY'
import glob, pandas as pd, os

base="14_BiGSCAPE/bigscape_out/network_files"
runs = sorted(glob.glob(f"{base}/*/"))
if not runs:
    print("ERROR: No BiG-SCAPE network_files found.")
    raise SystemExit(1)

run = runs[-1]
mix_dir = f"{run}/mix"
clustering_files = sorted(glob.glob(f"{mix_dir}/mix_clustering_c*.tsv"))

if not clustering_files:
    print("ERROR: No mix_clustering_c*.tsv found.")
    raise SystemExit(1)

print(f"Using clustering file: {clustering_files[-1]}")

for clust in clustering_files:
    df = pd.read_csv(clust, sep="\t")

    # Extract isolate name from filenames
    df["isolate"] = df["#BGC Name"].str.extract(r"(Fus_[A-Za-z0-9]+)")

    df["is_mibig"] = df["#BGC Name"].str.startswith("BGC")

    summary = (
        df.groupby("Family Number")
          .agg(
              n_bgcs=("#BGC Name", "count"),
              n_isolates=("isolate", "nunique"),
              any_mibig=("is_mibig", "any")
          )
          .reset_index()
    )

    summary["novel"] = ~summary["any_mibig"]

    out = clust.replace(".tsv", "_summary.csv")
    summary.to_csv(out, index=False)

    print(f"Wrote {out}: {len(summary)} families, {summary['novel'].sum()} novel")
PY

echo ""
echo "[$(date)] Step 14 complete."
echo "Open: ${BIGSCAPE_DIR}/bigscape_out/index.html"