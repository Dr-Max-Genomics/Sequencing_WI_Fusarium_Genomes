#!/usr/bin/env bash

# =======================================================================
# assembly_tracker.sh
# Purpose : Track every contig/scaffold across all processing stages for
#           a single isolate. Reports:
#             - Name (and renames) at each stage
#             - Length at each stage
#             - Which contigs were dropped and why
#             - Summary comparison table
#
# Usage   : bash scripts/assembly_tracker.sh <sample_id>
#           e.g., bash scripts/assembly_tracker.sh Fus_Bar01
#
# Run interactively — not a SLURM batch job.
# Assumes paths.sh is sourced (or BATCH_DIR is set in environment).
# =======================================================================

set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-/project/silage_microbiome/max.chi/fusarium_sequencing}"
source "${PROJECT_ROOT}/config/paths.sh"

SAMPLE_ID="${1:-}"
if [[ -z "${SAMPLE_ID}" ]]; then
    echo "Usage: bash scripts/assembly_tracker.sh <sample_id>" >&2
    echo "  e.g., bash scripts/assembly_tracker.sh Fus_Bar01" >&2
    exit 1
fi

# -----------------------------------------------------------------------
# Locate stage files for this sample
# -----------------------------------------------------------------------
# Stage files — update paths if your layout differs
FLYE_ASSEMBLY="${ASSEMBLY_DIR}/${SAMPLE_ID}_flye/assembly.fasta"
NAMED_ASSEMBLY="${ASSEMBLY_DIR}/${SAMPLE_ID}_flye/${SAMPLE_ID}_assembly.fasta"
SORTED_FA="${POLISHED_DIR}/${SAMPLE_ID}_sort.fa"
POLISHED_FA="${POLISHED_DIR}/${SAMPLE_ID}_polished.fasta"
MASKED_FA="${MASK_DIR}/${SAMPLE_ID}_masked.fa"

# Funannotate predict uses the funannotate_name — derive from manifest
# Look up funannotate_name from manifest by matching sample_id
FUN_NAME=$(awk -F'\t' -v sid="${SAMPLE_ID}" '$2==sid {print $6}' "${MANIFEST}" | head -1)
if [[ -z "${FUN_NAME}" ]]; then
    echo "WARN: could not find funannotate_name for ${SAMPLE_ID} in ${MANIFEST}" >&2
    FUN_NAME="FunAnnotate_${SAMPLE_ID}"
fi

PREDICT_GFF="${FUN_PREDICT_DIR}/${FUN_NAME}/predict_results"
ANNOTATE_DIR="${FUN_PREDICT_DIR}/${FUN_NAME}/annotate_results"

# -----------------------------------------------------------------------
# Helper: parse FASTA and output tab-separated contig_id, length
# -----------------------------------------------------------------------
fasta_lengths() {
    local fasta="$1"
    if [[ ! -f "${fasta}" ]]; then
        echo "(file not found: ${fasta})"
        return
    fi
    python3 - "${fasta}" <<'PYEOF'
import sys
fa = sys.argv[1]
name = None
length = 0
with open(fa) as f:
    for line in f:
        line = line.rstrip()
        if line.startswith('>'):
            if name:
                print(f"{name}\t{length}")
            name = line[1:].split()[0]
            length = 0
        else:
            length += len(line)
    if name:
        print(f"{name}\t{length}")
PYEOF
}

# -----------------------------------------------------------------------
# Helper: compare two contig sets and report dropped/renamed
# -----------------------------------------------------------------------
compare_stages() {
    local label_a="$1"
    local file_a="$2"
    local label_b="$3"
    local file_b="$4"
    local minlen="${5:-0}"    # optional: minimum length filter applied at stage B

    if [[ ! -f "${file_a}" || ! -f "${file_b}" ]]; then
        echo "  (one or both files missing — skipping comparison)"
        return
    fi

    python3 - "${file_a}" "${file_b}" "${label_a}" "${label_b}" "${minlen}" <<'PYEOF'
import sys

def parse_fasta(path):
    seqs = {}
    name = None
    length = 0
    with open(path) as f:
        for line in f:
            line = line.rstrip()
            if line.startswith('>'):
                if name: seqs[name] = length
                name = line[1:].split()[0]
                length = 0
            else:
                length += len(line)
    if name: seqs[name] = length
    return seqs

fa_a = sys.argv[1]
fa_b = sys.argv[2]
lab_a = sys.argv[3]
lab_b = sys.argv[4]
minlen = int(sys.argv[5])

a = parse_fasta(fa_a)
b = parse_fasta(fa_b)

only_in_a = set(a) - set(b)
only_in_b = set(b) - set(a)
in_both = set(a) & set(b)

print(f"  {lab_a}: {len(a)} sequences, total {sum(a.values()):,} bp")
print(f"  {lab_b}: {len(b)} sequences, total {sum(b.values()):,} bp")
print()

if only_in_a:
    print(f"  Dropped between {lab_a} → {lab_b} ({len(only_in_a)} sequences):")
    for name in sorted(only_in_a, key=lambda n: a[n], reverse=True):
        reason = f"below {minlen}bp minlength filter" if minlen and a[name] < minlen else "unknown reason"
        print(f"    {name:40s}  {a[name]:>10,} bp  — {reason}")

if only_in_b:
    print(f"  New in {lab_b} ({len(only_in_b)} sequences — renamed or split):")
    for name in sorted(only_in_b, key=lambda n: b[n], reverse=True):
        print(f"    {name:40s}  {b[name]:>10,} bp")

if in_both:
    changed = [(n, a[n], b[n]) for n in in_both if a[n] != b[n]]
    if changed:
        print(f"  Length changes in shared contigs ({len(changed)}):")
        for name, la, lb in sorted(changed, key=lambda x: abs(x[2]-x[1]), reverse=True)[:20]:
            print(f"    {name:40s}  {la:>10,} → {lb:>10,} bp  (Δ {lb-la:+,})")
PYEOF
}

# -----------------------------------------------------------------------
# Main report
# -----------------------------------------------------------------------
echo "========================================================"
echo " Assembly contig/scaffold tracker"
echo " Sample:   ${SAMPLE_ID}"
echo " Manifest: ${MANIFEST}"
echo " Date:     $(date)"
echo "========================================================"
echo

# -----------------------------------------------------------------------
# STAGE 1 — Flye raw assembly
# -----------------------------------------------------------------------
echo "── STAGE 1: Flye assembly ──────────────────────────────"
if [[ -f "${FLYE_ASSEMBLY}" ]]; then
    echo "  File: ${FLYE_ASSEMBLY}"
    count=$(grep -c "^>" "${FLYE_ASSEMBLY}")
    total=$(fasta_lengths "${FLYE_ASSEMBLY}" | awk '{s+=$2} END {print s}')
    echo "  Sequences: ${count}  |  Total: ${total} bp"
    echo
    echo "  All contigs (sorted by length desc):"
    printf "  %-40s %12s\n" "CONTIG_ID" "LENGTH_BP"
    fasta_lengths "${FLYE_ASSEMBLY}" | sort -t$'\t' -k2 -rn | \
        awk '{printf "  %-40s %12s\n", $1, $2}'
else
    echo "  File not found: ${FLYE_ASSEMBLY}"
fi
echo

# -----------------------------------------------------------------------
# STAGE 2 — After funannotate sort (minlen 1000)
# -----------------------------------------------------------------------
echo "── STAGE 2: funannotate sort (--minlen 1000) ───────────"
if [[ -f "${SORTED_FA}" ]]; then
    echo "  File: ${SORTED_FA}"
    echo
    echo "  Comparison: Flye → sorted"
    compare_stages "Flye" "${FLYE_ASSEMBLY}" "Sorted" "${SORTED_FA}" 1000
    echo
    echo "  Retained contigs (new names after sort):"
    printf "  %-40s %12s\n" "SCAFFOLD_ID" "LENGTH_BP"
    fasta_lengths "${SORTED_FA}" | sort -t$'\t' -k2 -rn | \
        awk '{printf "  %-40s %12s\n", $1, $2}'
else
    echo "  File not found: ${SORTED_FA}"
    echo "  (run 08_sort_earlgrey_mask.sh first)"
fi
echo

# -----------------------------------------------------------------------
# STAGE 3 — After dorado polish (if applicable)
# -----------------------------------------------------------------------
echo "── STAGE 3: dorado polish ──────────────────────────────"
if [[ -f "${POLISHED_FA}" ]]; then
    echo "  File: ${POLISHED_FA}"
    echo
    echo "  Comparison: Sorted → polished"
    compare_stages "Sorted" "${SORTED_FA}" "Polished" "${POLISHED_FA}" 0
    echo
    echo "  Polished scaffolds:"
    printf "  %-40s %12s\n" "SCAFFOLD_ID" "LENGTH_BP"
    fasta_lengths "${POLISHED_FA}" | sort -t$'\t' -k2 -rn | \
        awk '{printf "  %-40s %12s\n", $1, $2}'
else
    echo "  File not found: ${POLISHED_FA}"
    echo "  (run A05_alignment_polish.sh and transfer back to Ceres)"
fi
echo

# -----------------------------------------------------------------------
# STAGE 4 — After funannotate mask (soft-masked)
# -----------------------------------------------------------------------
echo "── STAGE 4: EarlGrey + funannotate mask ────────────────"
if [[ -f "${MASKED_FA}" ]]; then
    echo "  File: ${MASKED_FA}"
    echo
    echo "  Comparison: Polished → masked"
    compare_stages "Polished" "${POLISHED_FA}" "Masked" "${MASKED_FA}" 0
    echo
    echo "  Masked scaffolds:"
    printf "  %-40s %12s\n" "SCAFFOLD_ID" "LENGTH_BP"
    fasta_lengths "${MASKED_FA}" | sort -t$'\t' -k2 -rn | \
        awk '{printf "  %-40s %12s\n", $1, $2}'
else
    echo "  File not found: ${MASKED_FA}"
fi
echo

# -----------------------------------------------------------------------
# STAGE 5 — funannotate predict (GFF3 gene count per scaffold)
# -----------------------------------------------------------------------
echo "── STAGE 5: funannotate predict (gene count per scaffold)"
GFF3=$(find "${PREDICT_GFF}" -maxdepth 1 -name "*.gff3" 2>/dev/null | head -1)
if [[ -n "${GFF3}" && -f "${GFF3}" ]]; then
    echo "  GFF3: ${GFF3}"
    echo
    echo "  Genes per scaffold (gene features only):"
    printf "  %-40s %12s\n" "SCAFFOLD_ID" "GENE_COUNT"
    grep -v "^#" "${GFF3}" | awk '$3=="gene"' | \
        awk '{print $1}' | sort | uniq -c | sort -rn | \
        awk '{printf "  %-40s %12s\n", $2, $1}'
    echo
    # Scaffolds in masked FASTA with zero genes (→ antiSMASH empty scaffold problem)
    if [[ -f "${MASKED_FA}" ]]; then
        echo "  Scaffolds with NO genes (antiSMASH empty scaffold candidates):"
        fasta_lengths "${MASKED_FA}" | awk '{print $1}' | sort > /tmp/_all_scaffolds.txt
        grep -v "^#" "${GFF3}" | awk '$3=="gene" {print $1}' | sort -u > /tmp/_scaffolds_with_genes.txt
        comm -23 /tmp/_all_scaffolds.txt /tmp/_scaffolds_with_genes.txt | while read scaffold; do
            len=$(fasta_lengths "${MASKED_FA}" | awk -v s="${scaffold}" '$1==s {print $2}')
            printf "  %-40s %12s bp  ← antiSMASH would fail without --no-abort-on-invalid-records\n" \
                "${scaffold}" "${len}"
        done
        rm -f /tmp/_all_scaffolds.txt /tmp/_scaffolds_with_genes.txt
    fi
else
    echo "  GFF3 not found under ${PREDICT_GFF}"
    echo "  (run 09a_FUN_predict.sh first)"
fi
echo

# -----------------------------------------------------------------------
# SUMMARY TABLE
# -----------------------------------------------------------------------
echo "── SUMMARY: sequence counts across stages ──────────────"
printf "  %-30s %10s %15s\n" "STAGE" "SEQUENCES" "TOTAL_BP"
printf "  %-30s %10s %15s\n" "-----" "---------" "--------"

for stage_label stage_file in \
    "Flye_assembly" "${FLYE_ASSEMBLY}" \
    "Sorted_(minlen1000)" "${SORTED_FA}" \
    "Polished" "${POLISHED_FA}" \
    "Masked" "${MASKED_FA}"
do
    if [[ -f "${stage_file}" ]]; then
        n=$(grep -c "^>" "${stage_file}" 2>/dev/null || echo 0)
        bp=$(fasta_lengths "${stage_file}" | awk '{s+=$2} END {print s+0}')
        printf "  %-30s %10s %15s\n" "${stage_label}" "${n}" "${bp}"
    else
        printf "  %-30s %10s %15s\n" "${stage_label}" "—" "—"
    fi
done
echo

echo "========================================================"
echo " Done: ${SAMPLE_ID}"
echo "========================================================"
