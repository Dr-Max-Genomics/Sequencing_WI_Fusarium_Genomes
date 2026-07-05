#!/usr/bin/env bash
#SBATCH -A silage_microbiome
#SBATCH -N 1
#SBATCH -n 40
#SBATCH --mem=150G
#SBATCH -p ceres
#SBATCH -t 05:00:00
#SBATCH --job-name=synteny_analysis
#SBATCH --output=/dev/null
#
# CORRECTED synteny script (Fig 4c). Fixes vs used_scripts/03_synteny.sh:
#   BUG 1 (fatal): PAF_OUT interpolated the reference's FULL PATH into the output
#                  filename -> "paf/1_vs_/90daydata/.../ref.fasta.paf" -> every
#                  minimap2 redirect failed ("No such file or directory") and
#                  ZERO alignments were produced. Fixed: use basename of the ref.
#   BUG 2: the inner loop iterated over all species keys that mapped to only two
#          reference paths, so each query was aligned to the same ref multiple
#          times (duplicate work, overwritten PAFs). Fixed: each query is aligned
#          once to the single reference assigned to its species complex.
#   BUG 3: synteny-break awk used `NR>1 && a>x || b>x || c` — && binds tighter
#          than ||, so breaks were counted on row 1 and whenever b/c triggered
#          regardless of NR. Fixed with explicit parentheses.
#
# DESIGN NOTE (please read): samples 1-6 (FFSC: F. fujikuroi / proliferatum /
# subglutinans) are aligned to a F. proliferatum reference; samples 7-12
# (FSAMSC: F. graminearum / sporotrichioides) to a F. graminearum reference.
# This is reasonable at the species-COMPLEX level, but the cross-species members
# (fujikuroi & subglutinans vs the prol ref; sporotrichioides vs the gram ref)
# will show elevated "breaks" from species divergence, not true lineage-specific
# fission. Interpret Fig4c at the complex level, or supply a conspecific
# reference per species if you need species-level fission calls.

set -euo pipefail

export PROJECT_ROOT="/90daydata/silage_microbiome/max_seq/MSA_2026/stress_res"
export ANALYSIS_ROOT="${PROJECT_ROOT}/conference_figs"
export INPUT_DIR="${ANALYSIS_ROOT}/00_input"
export OUTPUT_DIR="${ANALYSIS_ROOT}/03_synteny"
export LOG_DIR="${ANALYSIS_ROOT}/logs"

mkdir -p "${OUTPUT_DIR}"/{paf,bed,fusions}
exec > "${LOG_DIR}/03_synteny_${SLURM_JOB_ID:-local}.log" 2>&1

echo "=== Synteny Analysis: Chromosomal Fissions (corrected) ==="

BARLIST="${ANALYSIS_ROOT}/barlist.tsv"
REF_DIR="${INPUT_DIR}/ref_genomes"
PROL_REF="${REF_DIR}/prol_ref_GCA_036288945.1_ASM3628894v1_genome.fasta"
GRAM_REF="${REF_DIR}/gram_ref_GCF_000240135.3_ASM24013v3_genome.fasta"
THREADS="${SLURM_NTASKS:-8}"

module load minimap2 2>/dev/null || echo "minimap2 not a module; assuming it is in PATH."

ALIGNMENT_SUMMARY="${OUTPUT_DIR}/synteny_pairwise.tsv"
printf "query_sample\tquery_species\tref_sample\tref_species\tnum_alignments\tmean_query_cov\tmean_ref_cov\tsynteny_breaks\n" > "$ALIGNMENT_SUMMARY"

BREAKPOINT_BED="${OUTPUT_DIR}/fusions/lineage_specific_breakpoints.bed"
printf "#chrom\tstart\tend\tbreak_type\tquery_sample\tquery_species\tref_sample\tref_species\n" > "$BREAKPOINT_BED"

# --- Align each isolate once, to the reference for its species complex ---
while IFS=$'\t' read -r sample species strain isolate; do
    [[ "$sample" == "sample" ]] && continue

    QUERY_FASTA="${INPUT_DIR}/genomes/${sample}.fasta"
    [[ -f "$QUERY_FASTA" ]] || { echo "  MISSING query ${QUERY_FASTA}"; continue; }

    if (( sample >= 1 && sample <= 6 )); then
        REF_FASTA="$PROL_REF"; REF_TAG="prol_ref"; REF_SPECIES="F. proliferatum(ref)"
    else
        REF_FASTA="$GRAM_REF"; REF_TAG="gram_ref"; REF_SPECIES="F. graminearum(ref)"
    fi
    [[ -f "$REF_FASTA" ]] || { echo "  MISSING ref ${REF_FASTA}"; continue; }

    # FIX 1: build a safe output filename from the reference BASENAME
    PAF_OUT="${OUTPUT_DIR}/paf/${sample}_vs_${REF_TAG}.paf"
    echo "  Aligning sample ${sample} (${species}) -> ${REF_TAG}"
    minimap2 -t "$THREADS" -x asm5 "$REF_FASTA" "$QUERY_FASTA" > "$PAF_OUT" 2>/dev/null || true

    [[ -s "$PAF_OUT" ]] || { echo "    no alignments for sample ${sample}"; continue; }

    NUM_ALIGNS=$(wc -l < "$PAF_OUT")
    MEAN_QUERY_COV=$(awk '{sum+=($4-$3); tot+=$2} END{if(tot>0) printf "%.2f", sum/tot*100; else print "NA"}' "$PAF_OUT")
    MEAN_REF_COV=$(awk '{sum+=($9-$8); tot+=$7}   END{if(tot>0) printf "%.2f", sum/tot*100; else print "NA"}' "$PAF_OUT")

    # FIX 3: parenthesised break condition (gap >10 kb on query or ref, or strand flip)
    SYNTENY_BREAKS=$(awk '
        NR>1 && ( ($4-pq > 10000) || ($9-pr > 10000) || ($5 != ps) ) { breaks++ }
        { pq=$4; pr=$9; ps=$5 }
        END { print breaks+0 }' "$PAF_OUT")

    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
        "$sample" "$species" "$REF_TAG" "$REF_SPECIES" \
        "$NUM_ALIGNS" "$MEAN_QUERY_COV" "$MEAN_REF_COV" "$SYNTENY_BREAKS" >> "$ALIGNMENT_SUMMARY"

    # breakpoint regions (gap >10 kb on the reference axis)
    awk -v q="$sample" -v qs="$species" -v rt="$REF_TAG" -v rs="$REF_SPECIES" '
        NR>1 && ($9-pr > 10000) { print $6"\t"pr"\t"$9"\tfission_candidate\t"q"\t"qs"\t"rt"\t"rs }
        { pr=$9 }' "$PAF_OUT" >> "$BREAKPOINT_BED"
done < "$BARLIST"

echo ""
echo "✓ synteny_pairwise.tsv:"
cat "$ALIGNMENT_SUMMARY"

# --- lineage-specific fissions summary (per species) ---
LINEAGE_FISSIONS="${OUTPUT_DIR}/fusions/lineage_specific_fissions.tsv"
printf "species\tn_isolates\tmean_synteny_breaks\tmax_synteny_breaks\n" > "$LINEAGE_FISSIONS"
awk -F'\t' 'NR>1 { n[$2]++; sum[$2]+=$8; if($8>mx[$2]) mx[$2]=$8 }
    END { for (s in n) printf "%s\t%d\t%.1f\t%d\n", s, n[s], sum[s]/n[s], mx[s] }' \
    "$ALIGNMENT_SUMMARY" >> "$LINEAGE_FISSIONS"

echo ""
echo "✓ lineage_specific_fissions.tsv:"
cat "$LINEAGE_FISSIONS"
echo ""
echo "=== Synteny Analysis Complete ==="
echo "Then regenerate Fig4c:"
echo "  python3 corrected_scripts/08_generate_figures.py ${ANALYSIS_ROOT} ${ANALYSIS_ROOT}/08_figures_corrected"
exit 0
