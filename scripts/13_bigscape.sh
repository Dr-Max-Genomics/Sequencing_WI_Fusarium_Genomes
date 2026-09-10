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
#     the antiSMASH directories are valid, so it "completes" having clustered
#     nothing, and the summary step below then fails with
#     "No BiG-SCAPE network_files found."
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

echo "[$(date)] bigscape CLI check (confirm 1.x vs 2.x flag/output conventions below):"
bigscape --help 2>&1 | head -30 || true
echo ""

PFAM_DIR="${PROJECT_ROOT}/DB_Databases/pfam"

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
    --mibig \
    --mix \
    --hybrids-off \
    --include_singletons \
    --include_gbk_str region

echo ""
echo "[$(date)] BiG-SCAPE clustering complete."

# -------------------------------
# Summaries — GCF statistics
# -------------------------------
echo ""
echo "[$(date)] Summarizing BiG-SCAPE clustering..."

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





[Wed Sep  9 07:24:19 PM CDT 2026] Step 14 — BiG-SCAPE
Batch dir       : /90daydata/silage_microbiome/max_seq/batch3_2026-May
Manifest        : /project/silage_microbiome/max.chi/fusarium_sequencing/config/manifests/batch3_2026-May_manifest.tsv
antiSMASH root  : /90daydata/silage_microbiome/max_seq/batch3_2026-May/12a_AntiSMASH_gbk
BiGSCAPE out    : /90daydata/silage_microbiome/max_seq/batch3_2026-May/14_BiGSCAPE

[Wed Sep  9 07:24:21 PM CDT 2026] bigscape CLI check (confirm 1.x vs 2.x flag/output conventions below):
usage: BiG-SCAPE [-h] [-l LABEL] [-i INPUTDIR] -o OUTPUTDIR
                 [--pfam_dir PFAM_DIR] [-c CORES]
                 [--include_gbk_str INCLUDE_GBK_STR [INCLUDE_GBK_STR ...]]
                 [--exclude_gbk_str EXCLUDE_GBK_STR [EXCLUDE_GBK_STR ...]]
                 [-v] [--include_singletons] [-d DOMAIN_OVERLAP_CUTOFF]
                 [-m MIN_BGC_SIZE] [--mix] [--no_classify]
                 [--banned_classes {PKSI,PKSother,NRPS,RiPPs,Saccharides,Terpene,PKS-NRP_Hybrids,Others} [{PKSI,PKSother,NRPS,RiPPs,Saccharides,Terpene,PKS-NRP_Hybrids,Others} ...]]
                 [--cutoffs CUTOFFS [CUTOFFS ...]] [--clans-off]
                 [--clan_cutoff CLAN_CUTOFF CLAN_CUTOFF] [--hybrids-off]
                 [--mode {global,glocal,auto}] [--anchorfile ANCHORFILE]
                 [--force_hmmscan] [--skip_ma] [--mibig] [--mibig21]
                 [--mibig14] [--mibig13] [--query_bgc QUERY_BGC]
                 [--domain_includelist] [--version]

optional arguments:
  -h, --help            show this help message and exit
  -l LABEL, --label LABEL
                        An extra label for this run (will be used as part of
                        the folder name within the network_files results)
  -i INPUTDIR, --inputdir INPUTDIR
                        Input directory of gbk files, if left empty, all gbk
                        files in current and lower directories will be used.
  -o OUTPUTDIR, --outputdir OUTPUTDIR
                        Output directory, this will contain all output data
                        files.
  --pfam_dir PFAM_DIR   Location of hmmpress-processed Pfam files. Default is
                        same location of BiG-SCAPE
  -c CORES, --cores CORES
                        Set the number of cores the script may use (default:
                        use all available cores)

Isolates detected:
  - Fus_Bar01
  - Fus_Bar02
  - Fus_Bar04
  - Fus_Bar05
  - Fus_Bar06
  - Fus_Bar07
  - Fus_Bar08

[Wed Sep  9 07:24:25 PM CDT 2026] Checking antiSMASH region GBK folders...
✓ Fus_Bar01: 61 region GBKs found
✓ Fus_Bar02: 65 region GBKs found
✓ Fus_Bar04: 48 region GBKs found
✓ Fus_Bar05: 64 region GBKs found
✓ Fus_Bar06: 47 region GBKs found
✓ Fus_Bar07: 63 region GBKs found
✓ Fus_Bar08: 61 region GBKs found

[Wed Sep  9 07:24:26 PM CDT 2026] Running BiG-SCAPE on antiSMASH output structure...

One or more of the necessary Pfam files (.h3f, .h3i, .h3m, .h3p) were not found
Please download the latest Pfam-A.hmm file from http://pfam.xfam.org/
Then use hmmpress on it, and use the --pfam_dir parameter to point to the location of the files

[Wed Sep  9 07:24:27 PM CDT 2026] BiG-SCAPE clustering complete.

[Wed Sep  9 07:24:27 PM CDT 2026] Summarizing BiG-SCAPE clustering...
Traceback (most recent call last):
  File "<stdin>", line 1, in <module>
ModuleNotFoundError: No module named 'pandas'