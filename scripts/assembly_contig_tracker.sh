#!/usr/bin/env bash
# =======================================================================
# assembly_contig_tracker.sh
# Purpose : Track contigs/scaffolds across processing stages for a single
#           isolate. Reports:
#             - Name (and renames) at each stage
#             - Length at each stage
#             - Which contigs were dropped and why
#             - Summary comparison table
#
# Usage   : bash scripts/assembly_contig_tracker.sh <sample_id>
#           e.g., bash scripts/assembly_contig_tracker.sh Fus_Bar01
#
# Run interactively — not a SLURM batch job.
# Assumes paths.sh is sourced (or PROJECT_ROOT + config/paths.sh exist).
# =======================================================================

set -euo pipefail

# ------------------------------
# Parse sample ID from CLI
# ------------------------------
SAMPLE_ID="${1:-}"
if [[ -z "${SAMPLE_ID}" ]]; then
    echo "Usage: bash scripts/assembly_contig_tracker.sh <sample_id>" >&2
    echo "  e.g., bash scripts/assembly_contig_tracker.sh Fus_Bar01" >&2
    exit 1
fi

# ------------------------------
# Environment / paths
# ------------------------------
PROJECT_ROOT="${PROJECT_ROOT:-/project/silage_microbiome/max.chi/fusarium_sequencing}"
# This should set variables like ASSEMBLY_DIR, POLISHED_DIR, MASK_DIR, FUN_PREDICT_DIR, MANIFEST, etc.
source "${PROJECT_ROOT}/config/paths.sh"

# ------------------------------
# Per-sample report filename (dynamic)
# ------------------------------
REPORT="assembly_report_${SAMPLE_ID}_$(date +%Y%m%d_%H%M).txt"
exec >"$REPORT" 2>&1

# ------------------------------
# Locate stage files for this sample
# ------------------------------
FLYE_ASSEMBLY="${ASSEMBLY_DIR}/${SAMPLE_ID}_flye/assembly.fasta"
SORTED_FA="${POLISHED_DIR}/${SAMPLE_ID}_sort.fa"
POLISHED_FA="${POLISHED_DIR}/${SAMPLE_ID}_polished.fasta"
MASKED_FA="${MASK_DIR}/${SAMPLE_ID}_masked.fa"

# Funannotate predict uses the funannotate_name — derive from manifest
FUN_NAME=$(awk -F'\t' -v sid="${SAMPLE_ID}" '$2==sid {print $6}' "${MANIFEST}" | head -1)
if [[ -z "${FUN_NAME}" ]]; then
    echo "WARN: could not find funannotate_name for ${SAMPLE_ID} in ${MANIFEST}" >&2
    FUN_NAME="FunAnnotate_${SAMPLE_ID}"
fi
PREDICT_GFF_DIR="${FUN_PREDICT_DIR}/${FUN_NAME}/predict_results"

# ------------------------------
# Helper: parse FASTA and output tab-separated contig_id, length
# ------------------------------
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

# ------------------------------
# Helper: compare two contig sets by MD5 (sequence content)
# Reports renames explicitly; filters by minlen when provided
# ------------------------------
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
import sys, hashlib

def index_fasta(path):
    # Returns dict: name -> (length, md5)
    seqs = {}
    name = None
    buf = []
    with open(path) as f:
        for line in f:
            line = line.rstrip()
            if line.startswith('>'):
                if name is not None:
                    seq = ''.join(buf)
                    md5 = hashlib.md5(seq.encode()).hexdigest()
                    seqs[name] = (len(seq), md5)
                name = line[1:].split()[0]
                buf = []
            else:
                buf.append(line)
    if name is not None:
        seq = ''.join(buf)
        md5 = hashlib.md5(seq.encode()).hexdigest()
        seqs[name] = (len(seq), md5)
    return seqs

fa_a, fa_b, lab_a, lab_b, minlen = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], int(sys.argv[5])
A = index_fasta(fa_a)
B = index_fasta(fa_b)

lenA = sum(l for l,_ in A.values())
lenB = sum(l for l,_ in B.values())
print(f"  {lab_a}: {len(A)} sequences, total {lenA:,} bp")
print(f"  {lab_b}: {len(B)} sequences, total {lenB:,} bp")
print()

# Maps md5 -> name
md5_to_A = {md5: n for n,(l,md5) in A.items()}
md5_to_B = {md5: n for n,(l,md5) in B.items()}
md5A = set(md5_to_A); md5B = set(md5_to_B)

# Renames: same md5 present in both, different names
renamed = [(md5, md5_to_A[md5], md5_to_B[md5], A[md5_to_A[md5]][0])
           for md5 in sorted(md5A & md5B, key=lambda m: A[md5_to_A[m]][0], reverse=True)
           if md5_to_A[md5] != md5_to_B[md5]]
if renamed:
    print(f"  Renamed between {lab_a} → {lab_b} ({len(renamed)} sequences):")
    for _md5, old, new, L in renamed:
        print(f"    {old:40s} → {new:40s}  {L:>10,} bp")
    print()

# Dropped: md5 in A not present in B
dropped = [(n, A[n][0]) for n,(La,ma) in A.items() if ma not in md5B]
if dropped:
    print(f"  Dropped between {lab_a} → {lab_b} ({len(dropped)} sequences):")
    for n,L in sorted(dropped, key=lambda x: x[1], reverse=True):
        reason = f"below {minlen}bp minlength filter" if minlen and L < minlen else "sequence changed or filtered"
        print(f"    {n:40s}  {L:>10,} bp  — {reason}")
    print()

# New: md5 in B not present in A
newseqs = [(n, B[n][0]) for n,(Lb,mb) in B.items() if mb not in md5A]
if newseqs:
    print(f"  New in {lab_b} ({len(newseqs)} sequences):")
    for n,L in sorted(newseqs, key=lambda x: x[1], reverse=True):
        print(f"    {n:40s}  {L:>10,} bp")
    print()

# Modified sequences where the NAME is the same but MD5/length changed (true edits)
changed = []
for n,(La,ma) in A.items():
    if n in B:
        Lb, mb = B[n]
        if La != Lb or ma != mb:
            changed.append((n, La, Lb))
if changed:
    print(f"  Length/sequence changes in shared names ({len(changed)}):")
    for name, la, lb in sorted(changed, key=lambda x: abs(x[2]-x[1]), reverse=True)[:50]:
        print(f"    {name:40s}  {la:>10,} → {lb:>10,} bp  (Δ {lb-la:+,})")
PYEOF
}

# ------------------------------
# Main report
# ------------------------------
echo "========================================================"
echo " Assembly contig/scaffold tracker"
echo " Sample:   ${SAMPLE_ID}"
echo " Manifest: ${MANIFEST}"
echo " Date:     $(date)"
echo "========================================================"
echo

# ------------------------------
# STAGE 1 — Flye raw assembly
# ------------------------------
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

# ------------------------------
# STAGE 2 — After funannotate sort (minlen 1000)
# ------------------------------
echo "── STAGE 2: funannotate sort (--minlen 1000) ───────────"
if [[ -f "${SORTED_FA}" ]]; then
    echo "  File: ${SORTED_FA}"
    echo
    echo "  Comparison: Flye → Sorted"
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

# ------------------------------
# STAGE 3 — After dorado polish (if applicable)
# ------------------------------
echo "── STAGE 3: dorado polish ──────────────────────────────"
if [[ -f "${POLISHED_FA}" ]]; then
    echo "  File: ${POLISHED_FA}"
    echo
    echo "  Comparison: Sorted → Polished"
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

# ------------------------------
# STAGE 4 — After funannotate mask (soft-masked)
# ------------------------------
echo "── STAGE 4: EarlGrey + funannotate mask ────────────────"
if [[ -f "${MASKED_FA}" ]]; then
    echo "  File: ${MASKED_FA}"
    echo
    echo "  Comparison: Polished → Masked"
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

# ------------------------------
# STAGE 5 — funannotate predict (GFF3 gene count per scaffold)
# ------------------------------
echo "── STAGE 5: funannotate predict (gene count per scaffold)"
GFF3=$(find "${PREDICT_GFF_DIR}" -maxdepth 1 -name "*.gff3" 2>/dev/null | head -1 || true)
if [[ -n "${GFF3:-}" && -f "${GFF3}" ]]; then
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
        comm -23 /tmp/_all_scaffolds.txt /tmp/_scaffolds_with_genes.txt | while read -r scaffold; do
            len=$(fasta_lengths "${MASKED_FA}" | awk -v s="${scaffold}" '$1==s {print $2}')
            printf "  %-40s %12s bp  ← antiSMASH would fail without --no-abort-on-invalid-records\n" \
                "${scaffold}" "${len}"
        done
        rm -f /tmp/_all_scaffolds.txt /tmp/_scaffolds_with_genes.txt
    fi
else
    echo "  GFF3 not found under ${PREDICT_GFF_DIR}"
    echo "  (run 09a_FUN_predict.sh first)"
fi
echo

# ------------------------------
# SUMMARY TABLE
# ------------------------------
echo "── SUMMARY: sequence counts across stages ──────────────"
printf "  %-30s %10s %15s\n" "STAGE" "SEQUENCES" "TOTAL_BP"
printf "  %-30s %10s %15s\n" "-----" "---------" "--------"

stages=(
  "Flye_assembly" "${FLYE_ASSEMBLY}"
  "Sorted_(minlen1000)" "${SORTED_FA}"
  "Polished" "${POLISHED_FA}"
  "Masked" "${MASKED_FA}"
)

for ((i=0; i<${#stages[@]}; i+=2)); do
    stage_label="${stages[$i]}"
    stage_file="${stages[$i+1]}"

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
echo " Report: ${REPORT}"
echo "========================================================"