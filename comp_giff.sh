#!/usr/bin/env bash
#SBATCH -A silage_microbiome
#SBATCH -N 1
#SBATCH -n 8
#SBATCH --mem=40G
#SBATCH -p ceres
#SBATCH -t 1:00:00
#SBATCH --job-name=comp_gff

set -euo pipefail

# ───────────────────────────────────────────────────────────────
# CONFIGURATION
# ───────────────────────────────────────────────────────────────
OLD_DIR="/project/silage_microbiome/max.chi/test_gff_diffs/old_dir"
NEW_DIR="/project/silage_microbiome/max.chi/test_gff_diffs/new_dir"
COMPARE_OUT="/project/silage_microbiome/max.chi/test_gff_diffs/results"
BUSCO_DOWNLOADS="/project/silage_microbiome/max.chi/fusarium_sequencing/DB_Databases/busco_downloads"

mkdir -p "$COMPARE_OUT"

log() { echo -e "$1" | tee -a "$REPORT"; }

# Auto-detect files
detect_file() {
    local dir="$1"
    local ext="$2"
    local file
    file=$(ls "$dir"/*."$ext" 2>/dev/null | head -1 || true)
    if [[ -z "$file" ]]; then
        echo "ERROR: No *.$ext file found in $dir" >&2
        exit 1
    fi
    echo "$file"
}

OLD_GBK=$(detect_file "$OLD_DIR" "gbk")
OLD_GFF=$(detect_file "$OLD_DIR" "gff3")
OLD_PFA=$(detect_file "$OLD_DIR" "fa")

NEW_GBK=$(detect_file "$NEW_DIR" "gbk")
NEW_GFF=$(detect_file "$NEW_DIR" "gff3")
NEW_PFA=$(detect_file "$NEW_DIR" "fa")

SAMPLE=$(basename "$NEW_GBK" | sed 's/.gbk//')
REPORT="${COMPARE_OUT}/${SAMPLE}_comparison.txt"
: > "$REPORT"

log "=========================================================="
log " Comparing OLD vs NEW annotation runs"
log " SAMPLE: $SAMPLE"
log "=========================================================="
log ""
log " OLD GBK: $OLD_GBK"
log " NEW GBK: $NEW_GBK"
log ""

# ───────────────────────────────────────────────────────────────
# SECTION 1: Protein stats
# ───────────────────────────────────────────────────────────────
log "══════════════════════════════════════════════════════════"
log "  1. PROTEIN STATS"
log "══════════════════════════════════════════════════════════"

protein_stats() {
    local fa="$1"
    local label="$2"

    local count avg_len min_len max_len
    count=$(grep -c "^>" "$fa")

    read avg_len min_len max_len < <(
        awk '/^>/{if (seq) print length(seq); seq=""} !/^>/{seq=seq$0}
             END{if (seq) print length(seq)}' "$fa" |
        awk 'BEGIN{min=999999; max=0; sum=0; n=0}
             {n++; sum+=$1; if($1<min)min=$1; if($1>max)max=$1}
             END{printf "%.0f %d %d", sum/n, min, max}'
    )

    log ""
    log "  [$label]"
    log "    Protein count:  $count"
    log "    Avg length:     $avg_len aa"
    log "    Min length:     $min_len aa"
    log "    Max length:     $max_len aa"
}

protein_stats "$OLD_PFA" "OLD RUN"
protein_stats "$NEW_PFA" "NEW RUN"
log ""

# ───────────────────────────────────────────────────────────────
# SECTION 2: GBK functional annotation
# ───────────────────────────────────────────────────────────────
log "══════════════════════════════════════════════════════════"
log "  2. FUNCTIONAL ANNOTATION (GBK)"
log "══════════════════════════════════════════════════════════"

gbk_stats() {
    local gbk="$1"
    local label="$2"

    local total pfam go hypo smcog bgc annotated pfam_pct go_pct ann_pct

    total=$(grep -c "/protein_id=" "$gbk" || true)
    pfam=$(grep -c "/db_xref=\"PF" "$gbk" || true)
    go=$(grep -c "/db_xref=\"GO:" "$gbk" || true)
    hypo=$(grep -c "hypothetical protein" "$gbk" || true)
    smcog=$(grep -c "smCOG\|SMCOG" "$gbk" || true)
    bgc=$(grep -c "##antiSMASH\|cluster_type" "$gbk" || true)

    annotated=$((total - hypo))

    if [[ $total -gt 0 ]]; then
        pfam_pct=$(awk "BEGIN{printf \"%.1f\", ($pfam/$total)*100}")
        go_pct=$(awk "BEGIN{printf \"%.1f\", ($go/$total)*100}")
        ann_pct=$(awk "BEGIN{printf \"%.1f\", ($annotated/$total)*100}")
    else
        pfam_pct="N/A"; go_pct="N/A"; ann_pct="N/A"
    fi

    log ""
    log "  [$label]"
    log "    Total CDS:              $total"
    log "    Pfam annotated:         $pfam  ($pfam_pct%)"
    log "    GO terms:               $go  ($go_pct%)"
    log "    Non-hypothetical:       $annotated  ($ann_pct%)"
    log "    Hypothetical proteins:  $hypo"
    log "    smCOG:                  $smcog"
    log "    BGC features:           $bgc"
}

gbk_stats "$OLD_GBK" "OLD RUN"
gbk_stats "$NEW_GBK" "NEW RUN"
log ""

# ───────────────────────────────────────────────────────────────
# SECTION 3: BUSCO
# ───────────────────────────────────────────────────────────────
log "══════════════════════════════════════════════════════════"
log "  3. BUSCO COMPLETENESS"
log "══════════════════════════════════════════════════════════"

module load busco5 || true

run_busco() {
    local fa="$1"
    local label="$2"

    local outdir="${COMPARE_OUT}/busco_${label}"
    mkdir -p "$outdir"

    log ""
    log "  Running BUSCO on $label proteins..."

    busco \
        --in "$fa" \
        --out "${SAMPLE}_${label}" \
        --out_path "$outdir" \
        --lineage_dataset hypocreales_odb10 \
        --mode proteins \
        --offline \
        --download_path "$BUSCO_DOWNLOADS" \
        --cpus 8 \
        --force \
        >/dev/null 2>&1

    local summary
    summary=$(find "$outdir" -name "short_summary*.txt" | head -1)

    if [[ -s "$summary" ]]; then
        log ""
        log "  [$label] BUSCO summary:"
        grep -E "Complete|Fragmented|Missing|Total" "$summary" | sed 's/^/    /'
    else
        log "  WARNING: No BUSCO summary found for $label"
    fi
}

run_busco "$OLD_PFA" "old"
run_busco "$NEW_PFA" "new"
log ""

# ───────────────────────────────────────────────────────────────
# SECTION 4: funannotate compare
# ───────────────────────────────────────────────────────────────
log "══════════════════════════════════════════════════════════"
log "  4. FUNANNOTATE COMPARE"
log "══════════════════════════════════════════════════════════"

export APPTAINERENV_FUNANNOTATE_DB="/project/silage_microbiome/max.chi/fusarium_sequencing/DB_Databases/funannotate_db"
export AUGUSTUS_CONFIG_PATH="/project/silage_microbiome/max.chi/fusarium_sequencing/DB_Databases/augustus_config/config"

module load funannotate

FUN_OUT="${COMPARE_OUT}/funannotate_compare_${SAMPLE}"
mkdir -p "$FUN_OUT"

log ""
log "  Running funannotate compare..."
funannotate compare \
    --input "$OLD_GBK" "$NEW_GBK" \
    --out "$FUN_OUT" \
    --cpus 8

log "  funannotate compare complete"
log "  HTML report: $FUN_OUT/index.html"
log ""

# ───────────────────────────────────────────────────────────────
# DONE
# ───────────────────────────────────────────────────────────────
log "=========================================================="
log "  Report written to: $REPORT"
log "=========================================================="
