#!/usr/bin/env bash
#SBATCH -A silage_microbiome
#SBATCH -N 1
#SBATCH -n 32
#SBATCH --mem=128G
#SBATCH -p ceres
#SBATCH -t 05:00:00
#SBATCH --job-name=accessory_genome
#SBATCH --output=/dev/null
#
# CORRECTED accessory / pan-genome analysis (Fig 4b).
#
# Why the old used_scripts/02_accessory_genome.sh was wrong:
#   1. Presence/absence was built on locus_tag / gene-ID strings. The proteomes
#      use Funannotate IDs (FUN_000001…) that RESET per genome, so identical IDs
#      are DIFFERENT genes in different isolates -> the "shared" signal was an
#      artefact.
#   2. The per-isolate CORE count ignored col_idx and just counted every core
#      gene in the pangenome -> CORE = 11469 for ALL isolates -> ACCESSORY =
#      total - 11469 went NEGATIVE for the smaller graminearum genomes.
#   3. UNIQUE was overwritten in a loop -> "not shared with the LAST isolate".
#
# This version clusters PROTEIN SEQUENCES across all isolates into orthogroups
# with MMseqs2, then classifies orthogroups and counts, per isolate, how many of
# ITS proteins fall in core / accessory / unique orthogroups. Counts are
# non-negative and sum to each isolate's proteome size by construction.

set -euo pipefail

export PROJECT_ROOT="/90daydata/silage_microbiome/max_seq/MSA_2026/stress_res"
export ANALYSIS_ROOT="${PROJECT_ROOT}/conference_figs"
export INPUT_DIR="${ANALYSIS_ROOT}/00_input"
export OUTPUT_DIR="${ANALYSIS_ROOT}/02_accessory_genome"
export LOG_DIR="${ANALYSIS_ROOT}/logs"
BARLIST="${ANALYSIS_ROOT}/barlist.tsv"

mkdir -p "${OUTPUT_DIR}"
exec > "${LOG_DIR}/02_accessory_genome_${SLURM_JOB_ID:-local}.log" 2>&1
echo "=== Accessory / Pan-genome Analysis (corrected) ==="

# Clustering thresholds (tune as needed): 50% identity, 80% coverage.
MIN_SEQ_ID="${MIN_SEQ_ID:-0.5}"
COV="${COV:-0.8}"
THREADS="${SLURM_NTASKS:-16}"

module load mmseqs2 2>/dev/null || module load mmseqs 2>/dev/null || \
    echo "mmseqs2 not a module; assuming 'mmseqs' is in PATH (conda: mamba install -c bioconda mmseqs2)."

WORK="${OUTPUT_DIR}/mmseqs_work"
rm -rf "$WORK"; mkdir -p "$WORK"
COMBINED="${WORK}/all_proteins.faa"
: > "$COMBINED"

# 1. Concatenate proteomes, prefixing every header with the sample id so cluster
#    members can be mapped back to their isolate:  >S<sample>|<origid>
echo "Tagging and concatenating proteomes..."
while IFS=$'\t' read -r sample species strain isolate; do
    [[ "$sample" == "sample" ]] && continue
    FAA="${INPUT_DIR}/proteomes/${sample}.faa"
    [[ -f "$FAA" ]] || { echo "  WARNING: missing ${FAA}"; continue; }
    awk -v s="$sample" '/^>/{sub(/^>/,">S" s "|"); print $1; next} {print}' "$FAA" >> "$COMBINED"
done < "$BARLIST"
echo "  total proteins: $(grep -c '^>' "$COMBINED")"

# 2. Cluster into orthogroups
echo "Running mmseqs easy-cluster (min-seq-id=${MIN_SEQ_ID}, c=${COV})..."
mmseqs easy-cluster "$COMBINED" "${WORK}/clust" "${WORK}/tmp" \
    --min-seq-id "$MIN_SEQ_ID" -c "$COV" --cov-mode 0 --threads "$THREADS" >/dev/null
CLUSTER_TSV="${WORK}/clust_cluster.tsv"   # columns: representative <TAB> member
echo "  orthogroups: $(cut -f1 "$CLUSTER_TSV" | sort -u | wc -l)"

# 3. Build presence/absence + per-isolate core/accessory/unique counts (in Python)
python3 - "$CLUSTER_TSV" "$BARLIST" "$OUTPUT_DIR" <<'PY'
import sys, collections, csv
cluster_tsv, barlist, outdir = sys.argv[1], sys.argv[2], sys.argv[3]

samples, iso, sp = [], {}, {}
with open(barlist) as fh:
    r = csv.DictReader(fh, delimiter="\t")
    for row in r:
        s = row["sample"]; samples.append(s); iso[s] = row["isolate"]; sp[s] = row["species"]
N = len(samples)
core_thresh = N - 1  # >=11/12

# rep -> set of isolates ; (rep,isolate) -> member count
og_isolates = collections.defaultdict(set)
og_iso_count = collections.defaultdict(lambda: collections.Counter())
with open(cluster_tsv) as fh:
    for line in fh:
        rep, mem = line.rstrip("\n").split("\t")
        # member id is "S<sample>|<origid>"; recover the sample number
        m_s = mem.split("|", 1)[0].lstrip("S")
        og_isolates[rep].add(m_s)
        og_iso_count[rep][m_s] += 1

# classify each orthogroup
og_class = {}
for rep, isos in og_isolates.items():
    n = len(isos)
    og_class[rep] = "core" if n >= core_thresh else ("unique" if n == 1 else "accessory")

# presence/absence matrix
with open(f"{outdir}/gene_presence_absence.tsv", "w") as fh:
    fh.write("orthogroup\t" + "\t".join(samples) + "\tn_isolates\tclass\n")
    for rep in sorted(og_isolates):
        pa = ["1" if s in og_isolates[rep] else "0" for s in samples]
        fh.write(rep + "\t" + "\t".join(pa) + f"\t{len(og_isolates[rep])}\t{og_class[rep]}\n")

# per-isolate counts: sum of THIS isolate's proteins in core/accessory/unique OGs
core_c = collections.Counter(); acc_c = collections.Counter(); uniq_c = collections.Counter()
for rep, cnt in og_iso_count.items():
    cls = og_class[rep]
    for s, c in cnt.items():
        if cls == "core": core_c[s] += c
        elif cls == "unique": uniq_c[s] += c
        else: acc_c[s] += c

with open(f"{outdir}/accessory_summary.tsv", "w") as fh:
    fh.write("sample\tisolate\tspecies\ttotal_genes\tcore_genes\taccessory_genes\tunique_genes\n")
    for s in samples:
        core = core_c[s]; acc = acc_c[s]; uni = uniq_c[s]; tot = core + acc + uni
        fh.write(f"{s}\t{iso[s]}\t{sp[s]}\t{tot}\t{core}\t{acc}\t{uni}\n")

# pangenome-level summary
n_core = sum(1 for c in og_class.values() if c == "core")
n_acc  = sum(1 for c in og_class.values() if c == "accessory")
n_uni  = sum(1 for c in og_class.values() if c == "unique")
print(f"orthogroups: {len(og_class)}  core={n_core} accessory={n_acc} unique={n_uni}")
PY

echo ""
echo "✓ accessory_summary.tsv:"
cat "${OUTPUT_DIR}/accessory_summary.tsv"

# sanity: no negative accessory values possible now (sums are by construction)
rm -rf "$WORK"
echo ""
echo "=== Accessory Genome Analysis Complete ==="
echo "Then regenerate Fig4b:"
echo "  python3 corrected_scripts/08_generate_figures.py ${ANALYSIS_ROOT} ${ANALYSIS_ROOT}/08_figures_corrected"
exit 0
