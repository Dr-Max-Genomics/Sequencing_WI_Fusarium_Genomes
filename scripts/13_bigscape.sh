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
#   - ${BIGSCAPE_DIR}/
#       bigscape_out/
#       network_files/
#       clustering summaries
#
# Notes:
#   - No 14a/14b split needed.
#   - BiG-SCAPE input = antiSMASH output folders (direct).
#   - Isolate directories under ANTISMASH_DIR are keyed by manifest column $2
#     (sample_id), matching how antismash_file ("Fus_BarNN...") is named in
#     the manifest. Confirm with `ls ${ANTISMASH_DIR}` if this ever changes.
#
# CHANGELOG (this revision):
#   - Added an explicit, readable check that BIGSCAPE_DIR is set (paths.sh did
#     not define it as of the last review) instead of letting `set -u` kill
#     the script with a bare "unbound variable" error.
#   - Fixed `((valid_input_count++))`: under `set -e`, `((x++))` returns the
#     PRE-increment value as its exit status, so the very first successful
#     isolate (valid_input_count 0 -> 1) evaluated to 0 and was treated as a
#     failed command, silently killing the script before BiG-SCAPE ever ran.
#     Replaced with a plain arithmetic assignment, which has no such gotcha.
#   - Fixed the Python summary block: it hardcoded a path relative to the
#     job's working directory ("14_BiGSCAPE/bigscape_out/network_files")
#     instead of using ${BIGSCAPE_DIR}. Since the heredoc is quoted (<<'PY'),
#     bash never substituted into it anyway. BIGSCAPE_DIR is now exported and
#     read via os.environ inside Python.
#   - Logged `bigscape --help` up front. This script's flags (--inputdir,
#     --outputdir, --hybrids-off, --include_singletons, space-separated
#     --cutoffs) and the expected network_files/mix_clustering_c*.tsv output
#     layout match classic BiG-SCAPE 1.1.x. BiG-SCAPE 2.x uses a different
#     subcommand CLI (`bigscape cluster -i -o -p --gcf-cutoffs`) and a
#     different (SQLite-backed) output structure entirely. If the module on
#     this system resolves to 2.x, the command below will fail with an
#     argument error — check the logged --help output first.
#   - Added --include_gbk_str region. BiG-SCAPE's own file filter defaults to
#     matching "cluster" in filenames (antiSMASH 3/4 naming, e.g.
#     "*.cluster001.gbk"). antiSMASH 5+ renamed per-BGC output to
#     "*.region001.gbk" — which is what the bash validation loop above
#     already checks for and what Step 12a actually produces. Left at its
#     default, BiG-SCAPE silently finds ~0 matching input files even though
#   - Removed --mibig. This build of bigscape/1.1.9 auto-extracts its bundled
#     MIBiG reference zip into its own install directory the first time it's
#     used (.../site-packages/bigscape/Annotated_MIBiG_reference/...), which
#     sits inside a read-only container filesystem here and fails every run
#     with "OSError: [Errno 30] Read-only file system". 1.1.9 is the final
#     1.x release, so there's no point-release fix to pick up. Since
#     scripts/11a_antismash_compare.sh already pulls MIBiG knownclusterblast
#     hits straight from each isolate's antiSMASH JSON into
#     analyses/antismash_comparison/antismash_known_hits.tsv, that remains
#     the source of known-vs-novel calls; without --mibig, BiG-SCAPE's own
#     network just won't have MIBiG reference nodes sitting in it for visual
#     comparison. See the NOTE printed by the summary step below.
###############################################################################

# -------------------------------
# Load project configuration
# -------------------------------
PROJECT_ROOT="${PROJECT_ROOT:-/project/silage_microbiome/max.chi/fusarium_sequencing}"
# shellcheck disable=SC1091
source "${PROJECT_ROOT}/config/paths.sh"

# antiSMASH output root from your existing Step 12a:
#   ANTISMASH_DIR="${BATCH_DIR}/12a_AntiSMASH_gbk"

# Fail fast with a clear message rather than a bare "unbound variable" error
# if BIGSCAPE_DIR hasn't been added to config/paths.sh yet.
: "${BIGSCAPE_DIR:?BIGSCAPE_DIR is not set. Add it to config/paths.sh, e.g.: BIGSCAPE_DIR=\"\${BATCH_DIR}/14_BiGSCAPE\" (and add it to the mkdir -p list).}"

mkdir -p "${LOG_DIR}/bigscape" "${BIGSCAPE_DIR}"

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


PFAM_DIR="${PROJECT_ROOT}/DB_Databases/pfam_db"

# -------------------------------
# Collect isolates from manifest (column 2 = sample_id; see header note)
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
    valid_input_count=$((valid_input_count + 1))
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
    --mix \
    --hybrids-off \
    --include_singletons \
    --include_gbk_str region

echo ""
echo "[$(date)] BiG-SCAPE clustering complete."

if ! compgen -G "${BIGSCAPE_DIR}/bigscape_out/network_files"/*/ > /dev/null; then
    echo "ERROR: bigscape exited without error but produced no network_files output."
    echo "  Check the log above for warnings (e.g. missing Pfam index, no matching"
    echo "  input GBKs) — bigscape does not always exit non-zero on these."
    exit 1
fi

# -------------------------------
# Summaries — GCF statistics
# -------------------------------
echo ""
echo "[$(date)] Summarizing BiG-SCAPE clustering..."

# This job runs under sbatch, which starts a fresh, non-interactive shell —
# unlike an interactive/login-node script, it does NOT inherit any conda
# environment already active in your shell. `module load bigscape` only put
# bigscape's own dependencies on PATH, not pandas. Activate seq_env now,
# deliberately AFTER bigscape has already finished running, so it can't
# shadow anything the bigscape module needs on PATH.
module load miniconda
source activate seq_env

export BIGSCAPE_DIR

python3 - <<'PY'
import glob, os, pandas as pd

base = os.path.join(os.environ["BIGSCAPE_DIR"], "bigscape_out", "network_files")
runs = sorted(glob.glob(f"{base}/*/"))
if not runs:
    print(f"ERROR: No BiG-SCAPE network_files found under {base}")
    raise SystemExit(1)

run = runs[-1]
mix_dir = f"{run}/mix"
clustering_files = sorted(glob.glob(f"{mix_dir}/mix_clustering_c*.tsv"))

if not clustering_files:
    print(f"ERROR: No mix_clustering_c*.tsv found under {mix_dir}")
    raise SystemExit(1)

print(f"Found {len(clustering_files)} clustering file(s) under: {run}")
print("NOTE: this run did not use --mibig (see script header). 'is_mibig' will be "
      "False and 'novel' True for every family below — that reflects no MIBiG "
      "reference BGCs being present in this network, not a confirmed absence of "
      "known homologs. Cross-reference "
      "analyses/antismash_comparison/antismash_known_hits.tsv for actual "
      "known-vs-novel calls (from antiSMASH's own knownclusterblast results).")

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
