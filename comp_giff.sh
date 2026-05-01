#!/usr/bin/env bash
# compare_runs.sh
# Compares old vs new funannotate annotation outputs for one sample.
# Requires only: *.gbk, *.gff3, *.proteins.fa
#
# Usage:
#   bash compare_runs.sh <sample_id>
#   e.g. bash compare_runs.sh Bar49
#
# Set OLD_DIR and NEW_DIR below before running.

set -euo pipefail

SAMPLE="${1:-Bar49}"

# ── Edit these paths ──────────────────────────────────────────────────
OLD_DIR="/path/to/comparison/old_run/${SAMPLE}"
NEW_DIR="/path/to/comparison/new_run/${SAMPLE}"
COMPARE_OUT="/project/silage_microbiome/max.chi/fusarium_sequencing/comparison/results"
BUSCO_DOWNLOADS="/project/silage_microbiome/max.chi/fusarium_sequencing/DB_Databases/busco_downloads"
# ──────────────────────────────────────────────────────────────────────

mkdir -p "${COMPARE_OUT}"
REPORT="${COMPARE_OUT}/${SAMPLE}_comparison.txt"
: > "${REPORT}"   # clear/create report file

log() { echo "$@" | tee -a "${REPORT}"; }

log "=========================================================="
log "  Annotation comparison: ${SAMPLE}"
log "  $(date)"
log "=========================================================="
log ""

# ── Locate files ──────────────────────────────────────────────────────
OLD_GFF=$(ls "${OLD_DIR}"/*.gff3       2>/dev/null | head -1)
OLD_GBK=$(ls "${OLD_DIR}"/*.gbk        2>/dev/null | head -1)
OLD_PFA=$(ls "${OLD_DIR}"/*.proteins.fa 2>/dev/null | head -1)

NEW_GFF=$(ls "${NEW_DIR}"/*.gff3       2>/dev/null | head -1)
NEW_GBK=$(ls "${NEW_DIR}"/*.gbk        2>/dev/null | head -1)
NEW_PFA=$(ls "${NEW_DIR}"/*.proteins.fa 2>/dev/null | head -1)

for f in "$OLD_GFF" "$OLD_GBK" "$OLD_PFA" "$NEW_GFF" "$NEW_GBK" "$NEW_PFA"; do
    [[ -s "$f" ]] || { echo "ERROR: missing or empty file: $f" >&2; exit 1; }
done

log "Old run files:"
log "  GFF3:     $(basename $OLD_GFF)"
log "  GBK:      $(basename $OLD_GBK)"
log "  Proteins: $(basename $OLD_PFA)"
log ""
log "New run files:"
log "  GFF3:     $(basename $NEW_GFF)"
log "  GBK:      $(basename $NEW_GBK)"
log "  Proteins: $(basename $NEW_PFA)"
log ""

# ══════════════════════════════════════════════════════════════════════
# SECTION 1: Gene structure stats from GFF3
# ══════════════════════════════════════════════════════════════════════
log "══════════════════════════════════════════════════════════"
log "  1. GENE STRUCTURE (from GFF3)"
log "══════════════════════════════════════════════════════════"

gff_stats() {
    local gff="$1"
    local label="$2"

    local genes mrnas exons cdss introns avg_exons avg_gene_len

    genes=$(grep -P "\tgene\t"       "$gff" | grep -v "^#" | wc -l)
    mrnas=$(grep -P "\tmRNA\t"       "$gff" | grep -v "^#" | wc -l)
    exons=$(grep -P "\texon\t"       "$gff" | grep -v "^#" | wc -l)
    cdss=$(grep -P "\tCDS\t"        "$gff" | grep -v "^#" | wc -l)

    # Average exons per gene
    avg_exons=$(awk -v e="$exons" -v g="$genes" 'BEGIN { if (g>0) printf "%.2f", e/g; else print "N/A" }')

    # Average gene length (end - start for gene features)
    avg_gene_len=$(grep -P "\tgene\t" "$gff" | grep -v "^#" | \
        awk '{sum += ($5 - $4 + 1); count++} END { if (count>0) printf "%.0f", sum/count; else print "N/A" }')

    # Intron count (exons per mRNA minus 1, summed)
    introns=$(grep -P "\texon\t" "$gff" | grep -v "^#" | \
        awk '{match($9, /Parent=([^;]+)/, a); print a[1]}' | \
        sort | uniq -c | \
        awk '{sum += ($1 - 1)} END { print sum+0 }')

    log ""
    log "  [${label}]"
    log "  Genes:              ${genes}"
    log "  mRNAs (transcripts):${mrnas}"
    log "  Exons:              ${exons}"
    log "  CDS features:       ${cdss}"
    log "  Total introns:      ${introns}"
    log "  Avg exons/gene:     ${avg_exons}"
    log "  Avg gene length:    ${avg_gene_len} bp"
}

gff_stats "$OLD_GFF" "OLD RUN"
gff_stats "$NEW_GFF" "NEW RUN"
log ""

# ══════════════════════════════════════════════════════════════════════
# SECTION 2: Protein stats from proteins.fa
# ══════════════════════════════════════════════════════════════════════
log "══════════════════════════════════════════════════════════"
log "  2. PROTEIN STATS (from proteins.fa)"
log "══════════════════════════════════════════════════════════"

protein_stats() {
    local fa="$1"
    local label="$2"

    local count avg_len min_len max_len

    count=$(grep -c "^>" "$fa")

    # Length stats using awk
    read avg_len min_len max_len < <(
        awk '/^>/{if (seq) print length(seq); seq=""} !/^>/{seq=seq$0}
             END{if (seq) print length(seq)}' "$fa" | \
        awk 'BEGIN{min=999999; max=0; sum=0; n=0}
             {n++; sum+=$1; if($1<min)min=$1; if($1>max)max=$1}
             END{printf "%.0f %d %d", sum/n, min, max}'
    )

    log ""
    log "  [${label}]"
    log "  Protein count:      ${count}"
    log "  Avg length:         ${avg_len} aa"
    log "  Min length:         ${min_len} aa"
    log "  Max length:         ${max_len} aa"
}

protein_stats "$OLD_PFA" "OLD RUN"
protein_stats "$NEW_PFA" "NEW RUN"
log ""

# ══════════════════════════════════════════════════════════════════════
# SECTION 3: Functional annotation from GBK
# ══════════════════════════════════════════════════════════════════════
log "══════════════════════════════════════════════════════════"
log "  3. FUNCTIONAL ANNOTATION (from GBK)"
log "══════════════════════════════════════════════════════════"

gbk_stats() {
    local gbk="$1"
    local label="$2"

    # Total CDS features
    local total_cds pfam go note product hypothetical smcog bgc

    total_cds=$(grep -c "/protein_id=" "$gbk" || true)

    # Pfam hits
    pfam=$(grep -c "/db_xref=\"PF" "$gbk" || true)

    # GO terms
    go=$(grep -c "/db_xref=\"GO:" "$gbk" || true)

    # Genes with a non-hypothetical product name
    hypothetical=$(grep -c "hypothetical protein" "$gbk" || true)

    # smCOG (AntiSMASH BGC gene labels)
    smcog=$(grep -c "smCOG\|SMCOG" "$gbk" || true)

    # BGC cluster regions
    bgc=$(grep -c "##antiSMASH\|antismash.*cluster\|cluster_type" "$gbk" || true)

    # Genes with any note/product beyond hypothetical
    annotated=$((total_cds - hypothetical))
    if [[ $total_cds -gt 0 ]]; then
        pfam_pct=$(awk "BEGIN {printf \"%.1f\", ($pfam/$total_cds)*100}")
        go_pct=$(awk "BEGIN {printf \"%.1f\", ($go/$total_cds)*100}")
        ann_pct=$(awk "BEGIN {printf \"%.1f\", ($annotated/$total_cds)*100}")
    else
        pfam_pct="N/A"; go_pct="N/A"; ann_pct="N/A"
    fi

    log ""
    log "  [${label}]"
    log "  Total CDS:                  ${total_cds}"
    log "  With Pfam annotation:       ${pfam}  (${pfam_pct}%)"
    log "  With GO terms:              ${go}  (${go_pct}%)"
    log "  Non-hypothetical products:  ${annotated}  (${ann_pct}%)"
    log "  Hypothetical proteins:      ${hypothetical}"
    log "  smCOG annotations:          ${smcog}"
    log "  AntiSMASH BGC features:     ${bgc}"
}

gbk_stats "$OLD_GBK" "OLD RUN"
gbk_stats "$NEW_GBK" "NEW RUN"
log ""

# ══════════════════════════════════════════════════════════════════════
# SECTION 4: BUSCO completeness on proteins.fa
# ══════════════════════════════════════════════════════════════════════
log "══════════════════════════════════════════════════════════"
log "  4. BUSCO COMPLETENESS (proteins mode, hypocreales)"
log "══════════════════════════════════════════════════════════"

if ! command -v busco &>/dev/null; then
    module load busco5 2>/dev/null || true
fi

if command -v busco &>/dev/null; then
    for label in old new; do
        if [[ "$label" == "old" ]]; then fa="$OLD_PFA"; else fa="$NEW_PFA"; fi

        busco_out="${COMPARE_OUT}/busco_${label}_${SAMPLE}"
        mkdir -p "${busco_out}"

        log ""
        log "  Running BUSCO [${label^^} RUN] ..."

        busco \
            --in "$fa" \
            --out "${SAMPLE}_${label}" \
            --out_path "${busco_out}" \
            --lineage_dataset hypocreales_odb10 \
            --mode proteins \
            --offline \
            --download_path "${BUSCO_DOWNLOADS}" \
            --cpus 8 \
            --force \
            > /dev/null 2>&1

        summary=$(find "${busco_out}" -name "short_summary*.txt" | head -1)
        if [[ -s "$summary" ]]; then
            log ""
            log "  [${label^^} RUN] BUSCO summary:"
            grep -E "Complete|Fragmented|Missing|Total" "$summary" | \
                sed 's/^/    /' | tee -a "${REPORT}"
        else
            log "  WARNING: BUSCO summary not found for ${label} run"
        fi
    done
else
    log ""
    log "  BUSCO not available — run manually:"
    log "    module load busco5"
    log "    busco --in <proteins.fa> --lineage_dataset hypocreales_odb10 --mode proteins --offline --download_path ${BUSCO_DOWNLOADS} --cpus 8"
fi

log ""
log "=========================================================="
log "  Report written to: ${REPORT}"
log "=========================================================="
