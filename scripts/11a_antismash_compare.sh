#!/usr/bin/env bash

# =======================================================================
# 11a_antismash_compare.sh
# Purpose : Consolidate per-isolate antiSMASH results into cross-batch
#           comparison tables for downstream analysis (R/Python plots,
#           BiG-SCAPE input, comparative manuscripts, etc.).
#
# This is NOT a SLURM batch job. Run interactively or as a quick login-
# node task — it's pure JSON parsing, takes seconds.
#
# Usage   : bash scripts/11a_antismash_compare.sh
#           bash scripts/11a_antismash_compare.sh --batches batch_2025-Feb,batch_2025-Dec
#           bash scripts/11a_antismash_compare.sh --outdir /path/to/somewhere
#
# Inputs  : Each batch's manifest at config/manifests/{BATCH_ID}_manifest.tsv
#           Each isolate's JSON at:
#             /90daydata/silage_microbiome/max_seq/{BATCH_ID}/12a_AntiSMASH_gbk/{sample_id}/{sample_id}.json
#
# Outputs : ${OUTDIR}/antismash_summary_by_isolate.tsv
#             one row per isolate: counts, top hits, totals
#           ${OUTDIR}/antismash_regions_long.tsv
#             one row per region: full per-region detail across all isolates
#           ${OUTDIR}/antismash_product_matrix.tsv
#             isolate × product-type count matrix (for heatmaps)
#           ${OUTDIR}/antismash_known_hits.tsv
#             one row per region with a MIBiG known-cluster hit
# =======================================================================

set -euo pipefail

# -----------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------
PROJECT_ROOT="${PROJECT_ROOT:-/project/silage_microbiome/max.chi/fusarium_sequencing}"
SCRATCH_ROOT="/90daydata/silage_microbiome/max_seq"
MANIFESTS_DIR="${PROJECT_ROOT}/config/manifests"

# Default: discover all batches that have a manifest in the repo
DEFAULT_BATCHES=$(find "${MANIFESTS_DIR}" -maxdepth 1 -name "*_manifest.tsv" \
                  | sed 's|.*/||; s|_manifest.tsv$||' | sort | tr '\n' ',' | sed 's/,$//')

BATCHES="${DEFAULT_BATCHES}"
OUTDIR="${PROJECT_ROOT}/analyses/antismash_comparison"

# -----------------------------------------------------------------------
# Arg parsing
# -----------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --batches) BATCHES="$2"; shift 2;;
        --outdir)  OUTDIR="$2"; shift 2;;
        -h|--help)
            sed -n '/^# Usage/,/^# =====/p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) echo "Unknown arg: $1" >&2; exit 1;;
    esac
done

mkdir -p "${OUTDIR}"

# Output files
SUMMARY="${OUTDIR}/antismash_summary_by_isolate.tsv"
REGIONS="${OUTDIR}/antismash_regions_long.tsv"
MATRIX="${OUTDIR}/antismash_product_matrix.tsv"
KNOWNHITS="${OUTDIR}/antismash_known_hits.tsv"

echo "=========================================="
echo " antiSMASH cross-batch comparison"
echo " Batches:    ${BATCHES}"
echo " Output dir: ${OUTDIR}"
echo "=========================================="

# -----------------------------------------------------------------------
# Build the list of (batch, sample_id, json_path) tuples we'll process
# Each manifest's first column is barcode, second is sample_id (9 cols total).
# -----------------------------------------------------------------------
JOBS_TSV=$(mktemp)
trap 'rm -f "${JOBS_TSV}"' EXIT

IFS=',' read -ra batch_array <<< "${BATCHES}"
for batch in "${batch_array[@]}"; do
    manifest="${MANIFESTS_DIR}/${batch}_manifest.tsv"
    if [[ ! -s "${manifest}" ]]; then
        echo "WARN: manifest missing for ${batch}: ${manifest}" >&2
        continue
    fi

    batch_dir="${SCRATCH_ROOT}/${batch}"
    antismash_dir="${batch_dir}/12a_AntiSMASH_gbk"

    # Skip header (NR>1), pull sample_id column (col 2)
    awk -F'\t' -v batch="${batch}" -v adir="${antismash_dir}" \
        'NR>1 {
            json = adir "/" $2 "/" $2 ".json"
            print batch "\t" $2 "\t" json
        }' "${manifest}" >> "${JOBS_TSV}"
done

total_isolates=$(wc -l < "${JOBS_TSV}")
echo "Found ${total_isolates} isolate(s) across ${#batch_array[@]} batch(es)."
echo

if (( total_isolates == 0 )); then
    echo "ERROR: no isolates to process. Exiting." >&2
    exit 1
fi

# -----------------------------------------------------------------------
# Single Python pass over all JSON files — extract everything we need
# -----------------------------------------------------------------------
export JOBS_TSV SUMMARY REGIONS MATRIX KNOWNHITS

python3 - <<'PYEOF'
import json
import os
import sys
from collections import defaultdict, Counter

jobs_tsv  = os.environ['JOBS_TSV']
summary   = os.environ['SUMMARY']
regions   = os.environ['REGIONS']
matrix    = os.environ['MATRIX']
knownhits = os.environ['KNOWNHITS']

# Open output files
summary_fh   = open(summary,   'w')
regions_fh   = open(regions,   'w')
knownhits_fh = open(knownhits, 'w')

summary_fh.write('\t'.join([
    'batch', 'sample_id', 'json_found',
    'antismash_version', 'taxon',
    'n_records', 'n_regions',
    'n_with_known_hit', 'n_with_high_conf_hit',
    'product_types_seen', 'total_bp_in_regions'
]) + '\n')

regions_fh.write('\t'.join([
    'batch', 'sample_id', 'record_id', 'region_number',
    'products', 'start', 'end', 'length_bp',
    'top_known_cluster', 'top_known_similarity', 'top_known_confidence'
]) + '\n')

knownhits_fh.write('\t'.join([
    'batch', 'sample_id', 'record_id', 'region_number',
    'products', 'known_cluster_name', 'known_cluster_type',
    'similarity_pct', 'confidence', 'mibig_id'
]) + '\n')

# Track product matrix: dict of {(batch, sample) -> Counter of products}
product_matrix = defaultdict(Counter)
all_product_types = set()
isolates_in_order = []

# Process each isolate
with open(jobs_tsv) as f:
    rows = [line.rstrip('\n').split('\t') for line in f if line.strip()]

for batch, sample_id, json_path in rows:
    isolates_in_order.append((batch, sample_id))

    if not os.path.isfile(json_path):
        summary_fh.write('\t'.join([
            batch, sample_id, 'False', '', '', '0', '0', '0', '0', '', '0'
        ]) + '\n')
        print(f"  MISSING: {batch}/{sample_id}: {json_path}", file=sys.stderr)
        continue

    try:
        with open(json_path) as jf:
            data = json.load(jf)
    except Exception as e:
        print(f"  ERROR reading {json_path}: {e}", file=sys.stderr)
        summary_fh.write('\t'.join([
            batch, sample_id, 'False', '', '', '0', '0', '0', '0', '', '0'
        ]) + '\n')
        continue

    version  = data.get('version', '')
    taxon    = data.get('taxon', '')
    records  = data.get('records', [])

    n_records = len(records)
    n_regions = 0
    n_with_known = 0
    n_high_conf  = 0
    total_bp = 0
    sample_products = set()

    # Walk records and their region features
    for rec in records:
        rec_id = rec.get('id', '')
        # Region features live in rec['features'] with type 'region'
        features = rec.get('features', [])
        for feat in features:
            if feat.get('type') != 'region':
                continue
            n_regions += 1

            # Region location  e.g., [42561:78092](+) or {'start':..., 'end':...}
            loc = feat.get('location', '')
            start = end = 0
            length = 0
            try:
                # antiSMASH stores locations as strings like "[start:end](strand)"
                if isinstance(loc, str) and ':' in loc:
                    inner = loc.strip('[]').split(']')[0]
                    s, e = inner.split(':')
                    start = int(s.lstrip('<>'))
                    end   = int(e.lstrip('<>'))
                    length = end - start
            except Exception:
                pass
            total_bp += length

            quals = feat.get('qualifiers', {})
            # /product=  → list of product types (one region can have multiple)
            products = quals.get('product', [])
            products_str = ';'.join(products) if products else ''
            for p in products:
                sample_products.add(p)
                product_matrix[(batch, sample_id)][p] += 1
                all_product_types.add(p)

            # Region number (from /region_number=)
            region_num = quals.get('region_number', [''])[0]

            # Known cluster best hit — antiSMASH stores knownclusterblast results
            # in rec['modules']['antismash.modules.clusterblast']
            top_known = ''
            top_sim   = ''
            top_conf  = ''
            mibig_id  = ''
            top_type  = ''

            cb_mod = rec.get('modules', {}).get('antismash.modules.clusterblast', {})
            if cb_mod:
                # knowncluster results may be under 'knowncluster' or 'general'
                knowncluster = cb_mod.get('knowncluster', cb_mod.get('results', {}))
                # Different antismash versions structure this differently.
                # Look for a list of hits associated with this region.
                region_hits = []
                if isinstance(knowncluster, dict):
                    for k, v in knowncluster.items():
                        if str(k) == str(region_num) and isinstance(v, list):
                            region_hits = v
                            break
                elif isinstance(knowncluster, list):
                    # flat list — try to filter by region
                    region_hits = [h for h in knowncluster
                                   if isinstance(h, dict) and
                                   str(h.get('region_number','')) == str(region_num)]

                if region_hits:
                    best = region_hits[0]
                    if isinstance(best, dict):
                        top_known = best.get('description', best.get('name', ''))
                        top_sim   = best.get('similarity', '')
                        top_conf  = best.get('confidence', '')
                        mibig_id  = best.get('accession', best.get('mibig_id', ''))
                        top_type  = best.get('cluster_type', '')

                    if top_known:
                        n_with_known += 1
                        if str(top_conf).lower() == 'high':
                            n_high_conf += 1

                    # Write to known hits TSV (top 3 per region)
                    for hit in region_hits[:3]:
                        if not isinstance(hit, dict):
                            continue
                        knownhits_fh.write('\t'.join([
                            batch, sample_id, rec_id, str(region_num),
                            products_str,
                            str(hit.get('description', hit.get('name', ''))),
                            str(hit.get('cluster_type', '')),
                            str(hit.get('similarity', '')),
                            str(hit.get('confidence', '')),
                            str(hit.get('accession', hit.get('mibig_id', ''))),
                        ]) + '\n')

            regions_fh.write('\t'.join([
                batch, sample_id, rec_id, str(region_num),
                products_str, str(start), str(end), str(length),
                top_known, str(top_sim), str(top_conf)
            ]) + '\n')

    summary_fh.write('\t'.join([
        batch, sample_id, 'True',
        version, taxon,
        str(n_records), str(n_regions),
        str(n_with_known), str(n_high_conf),
        ';'.join(sorted(sample_products)),
        str(total_bp)
    ]) + '\n')
    print(f"  ✓ {batch}/{sample_id}: {n_regions} regions, "
          f"{n_with_known} with MIBiG hit ({n_high_conf} high-conf)")

summary_fh.close()
regions_fh.close()
knownhits_fh.close()

# Build product matrix TSV (isolate × product type counts)
sorted_products = sorted(all_product_types)
with open(matrix, 'w') as mf:
    mf.write('\t'.join(['batch', 'sample_id'] + sorted_products) + '\n')
    for (batch, sample_id) in isolates_in_order:
        counts = product_matrix.get((batch, sample_id), Counter())
        row = [batch, sample_id] + [str(counts.get(p, 0)) for p in sorted_products]
        mf.write('\t'.join(row) + '\n')

print(f"\nProcessed {len(isolates_in_order)} isolate(s).")
print(f"Product types seen across all isolates: {len(sorted_products)}")
PYEOF

# -----------------------------------------------------------------------
# Report what we produced
# -----------------------------------------------------------------------
echo
echo "=========================================="
echo " Output files written:"
echo "=========================================="
for f in "${SUMMARY}" "${REGIONS}" "${MATRIX}" "${KNOWNHITS}"; do
    if [[ -s "$f" ]]; then
        lines=$(wc -l < "$f")
        size=$(du -sh "$f" | cut -f1)
        printf "  %-60s %6s lines  %6s\n" "$(basename "$f")" "${lines}" "${size}"
    else
        printf "  %-60s (empty or missing)\n" "$(basename "$f")"
    fi
done

# Quick summary view
echo
echo "Per-isolate summary preview:"
column -t -s $'\t' "${SUMMARY}" 2>/dev/null | head -20 || head -20 "${SUMMARY}"

echo
echo "Done. Files in: ${OUTDIR}"
