#!/usr/bin/env bash
#SBATCH -A silage_microbiome
#SBATCH -N 1
#SBATCH -n 32
#SBATCH --mem=100G
#SBATCH -p ceres
#SBATCH -t 6:00:00
#SBATCH --job-name=antiSMASH
#SBATCH --array=1-9
#SBATCH --output=/dev/null

set -euo pipefail

# =======================================================================
# 11_antismash.sh
# Purpose : Identify biosynthetic gene clusters (BGCs) using antiSMASH v8.
# Input   : annotate_results/*_new.gbk  (funannotate annotate output)
# Output  : 12a_AntiSMASH_gbk/{sample_id}/  (full antiSMASH results dir)
#           12a_AntiSMASH_gbk/{sample_id}.gbk  (GBK symlink for 09c_FUN_annotate)
# Usage   : sbatch --array=1 scripts/11_antismash.sh     # test one
#           sbatch --array=2-9 scripts/11_antismash.sh   # rest of batch
# -----------------------------------------------------------------------
# FLAGS used (reconstructed from web JSON + cb-knownclusters):
#   --taxon fungi                   organism type
#   --cb-general                    ClusterBlast: vs antiSMASH database
#   --cb-knownclusters              KnownClusterBlast: vs MIBiG. Required for
#                                   the "Similarity" + "Most similar known
#                                   cluster" columns on the overview page.
#                                   In v8, similarity is shown as confidence
#                                   levels (high ≥75%, medium 50-75%,
#                                   low 15-50%); hits <15% are not shown.
#   --cc-mibig                      ClusterCompare: detailed MIBiG comparison
#   --clusterhmmer                  Pfam annotation on cluster regions only
#   --tigrfam                       TIGRfam domain annotation
#   --pfam2go                       Map Pfam domains to Gene Ontology terms
#   --rre                           RREFinder: detect RiPP recognition elements
#   --genefinding-tool none         Skip gene finding (funannotate did it).
#                                   Also handles empty scaffolds without abort.
#   --minlength 1000                Skip scaffolds shorter than 1000 bp.
#   --allow-long-headers            Permit long LOCUS lines in GBK input.
#                                   funannotate's renamed scaffolds can exceed
#                                   the strict GenBank LOCUS spec; without this
#                                   antiSMASH can crash on those records.
#   --logfile / -v                  Write antiSMASH's internal log alongside
#                                   results (separate from the SLURM log).
#                                   Useful for triaging per-region warnings.
# NOT run: --smcog-trees, --cb-subclusters, --fullhmmer
# -----------------------------------------------------------------------
# Post-run sanity checks (see end of script):
#   - flag samples with zero BGC regions (Fusarium typically has 30-50)
#   - surface warnings/errors from antiSMASH's internal log
#   - report region counts by type for quick QC at a glance
# -----------------------------------------------------------------------

PROJECT_ROOT="${PROJECT_ROOT:-/project/silage_microbiome/max.chi/fusarium_sequencing}"
source "${PROJECT_ROOT}/config/paths.sh"

# -----------------------------------------------------------------------
# Standard manifest read — all 9 columns. See README §7.
# -----------------------------------------------------------------------
LINE_NUM=$((SLURM_ARRAY_TASK_ID + 1))
IFS=$'\t' read -r \
    barcode sample_id assembly_file busco_name earlgrey_species \
    funannotate_name funannotate_species protein_evidence_file antismash_file \
    < <(sed -n "${LINE_NUM}p" "${MANIFEST}")

if [[ -z "${sample_id:-}" ]]; then
    echo "ERROR: no sample at manifest line ${LINE_NUM} of ${MANIFEST}" >&2
    exit 1
fi

# -----------------------------------------------------------------------
# Paths
# -----------------------------------------------------------------------
# Input: the _new.gbk from funannotate annotate
# Use -print -quit (not |head) — pipelines can SIGPIPE under set -o pipefail
ANNOTATE_DIR="${FUN_PREDICT_DIR}/${funannotate_name}/annotate_results"
INPUT_GBK=$(find "${ANNOTATE_DIR}" -maxdepth 1 -name "*_new.gbk" -print -quit)

# Output directory per sample
OUT_DIR="${ANTISMASH_DIR}/${sample_id}"

# GBK symlink expected by 09c_FUN_annotate.sh (antismash_file in manifest)
GBK_LINK="${ANTISMASH_DIR}/${antismash_file}"

mkdir -p "${ANTISMASH_DIR}" "${LOG_DIR}/antismash"
log_file="${LOG_DIR}/antismash/${sample_id}.log"
exec >"${log_file}" 2>&1

echo "=========================================="
echo "[$(date)] antiSMASH v8 BGC analysis"
echo "Sample:      ${sample_id}"
echo "Input GBK:   ${INPUT_GBK:-NOT FOUND}"
echo "Output dir:  ${OUT_DIR}"
echo "Manifest:    ${MANIFEST}"
echo "Job ID:      ${SLURM_JOB_ID} / task ${SLURM_ARRAY_TASK_ID}"
echo "Host:        $(hostname)"
echo "=========================================="

# Validate input
if [[ -z "${INPUT_GBK}" || ! -s "${INPUT_GBK}" ]]; then
    echo "ERROR: no *_new.gbk found in ${ANNOTATE_DIR}" >&2
    ls "${ANNOTATE_DIR}" >&2 || true
    echo "Did 09c_FUN_annotate.sh complete for ${sample_id}?" >&2
    exit 1
fi

echo "Input GBK confirmed: ${INPUT_GBK}"
echo "Input GBK size:      $(du -sh "${INPUT_GBK}" | cut -f1)"

# Skip if already done (check for antiSMASH index.html as completion signal)
if [[ -f "${OUT_DIR}/index.html" ]]; then
    echo "antiSMASH output exists — skipping: ${OUT_DIR}"
    # Still ensure the GBK symlink exists for 09c_FUN_annotate
    if [[ ! -e "${GBK_LINK}" ]]; then
        shopt -s nullglob
        gbk_files=( "${OUT_DIR}"/*.gbk )
        shopt -u nullglob
        (( ${#gbk_files[@]} > 0 )) && ln -sfn "${gbk_files[0]}" "${GBK_LINK}"
    fi
    exit 0
fi

# -----------------------------------------------------------------------
# Run antiSMASH
# -----------------------------------------------------------------------
module load antismash

echo "[$(date)] Running antiSMASH..."

antismash \
    --taxon fungi \
    --cb-general \
    --cb-knownclusters \
    --cc-mibig \
    --clusterhmmer \
    --tigrfam \
    --pfam2go \
    --rre \
    --genefinding-tool none \
    --minlength 1000 \
    --allow-long-headers \
    --logfile "${OUT_DIR}/antismash_run.log" \
    -v \
    --cpus "${SLURM_NTASKS}" \
    --output-dir "${OUT_DIR}" \
    --output-basename "${sample_id}" \
    "${INPUT_GBK}"

# Verify completion
if [[ ! -f "${OUT_DIR}/index.html" ]]; then
    echo "ERROR: antiSMASH index.html missing — run may have failed" >&2
    ls "${OUT_DIR}" >&2 || true
    exit 1
fi

# -----------------------------------------------------------------------
# Create GBK symlink for 09c_FUN_annotate.sh
# The manifest antismash_file column points to this path.
# Use a bash glob (no pipeline → no SIGPIPE possible under set -o pipefail).
# -----------------------------------------------------------------------
shopt -s nullglob
gbk_files=( "${OUT_DIR}"/*.gbk )
shopt -u nullglob

if (( ${#gbk_files[@]} > 0 )); then
    gbk_out="${gbk_files[0]}"
    ln -sfn "${gbk_out}" "${GBK_LINK}"
    echo "GBK symlink created: ${GBK_LINK} → ${gbk_out}"
else
    echo "WARN: no .gbk found in ${OUT_DIR} — symlink not created" >&2
fi

echo
echo "[$(date)] Done: ${sample_id}"
echo "Results: ${OUT_DIR}"

# -----------------------------------------------------------------------
# POST-RUN SANITY BLOCK
# -----------------------------------------------------------------------
echo
echo "=========================================="
echo "  POST-RUN SANITY CHECKS"
echo "=========================================="

# 1) Region count — count *.region*.gbk files (one per detected BGC)
shopt -s nullglob
region_files=( "${OUT_DIR}"/*.region*.gbk )
shopt -u nullglob
region_count=${#region_files[@]}

echo "BGC regions detected: ${region_count}"

# 2) Zero-region red flag
# Fusarium spp. are heavy SM producers (typically 30-50 regions).
# Zero regions is almost certainly an upstream/input problem.
if (( region_count == 0 )); then
    echo
    echo "🛑 ZERO BGC REGIONS DETECTED for ${sample_id}" >&2
    echo "   Fusarium isolates typically have 30-50 regions." >&2
    echo "   Possible causes:" >&2
    echo "     - input GBK had no annotated genes" >&2
    echo "     - --taxon was wrong" >&2
    echo "     - all scaffolds below --minlength threshold" >&2
    echo "   Inspect: ${OUT_DIR}/antismash_run.log" >&2
elif (( region_count < 20 )); then
    echo
    echo "⚠️  Lower than typical BGC count (${region_count} regions)" >&2
    echo "   Most Fusarium have 30-50. Worth a manual look at the overview." >&2
elif (( region_count > 80 )); then
    echo
    echo "⚠️  Higher than typical BGC count (${region_count} regions)" >&2
    echo "   May indicate over-fragmented assembly producing duplicate calls." >&2
fi

# 3) Region count by product type — quick at-a-glance QC
echo
echo "Region products (top-level types):"
if (( region_count > 0 )); then
    # Each region GBK contains a 'product' qualifier in its first FEATURES region entry.
    # Use grep to pull /product="..." lines and tally.
    for f in "${region_files[@]}"; do
        grep -m1 '/product=' "$f" 2>/dev/null | head -1 | \
            sed -E 's/.*\/product="([^"]+)".*/\1/'
    done | sort | uniq -c | sort -rn | sed 's/^/  /'
else
    echo "  (none — see warning above)"
fi

# 4) Warnings/errors surfaced from antiSMASH's internal log
antismash_log="${OUT_DIR}/antismash_run.log"
if [[ -s "${antismash_log}" ]]; then
    echo
    warn_count=$(grep -cE 'WARNING|ERROR|Skipping' "${antismash_log}" 2>/dev/null || echo 0)
    if (( warn_count > 0 )); then
        echo "⚠️  ${warn_count} WARNING/ERROR/Skipping lines in antismash_run.log"
        echo "   First 10 lines below (full log at ${antismash_log}):"
        grep -E 'WARNING|ERROR|Skipping' "${antismash_log}" 2>/dev/null | \
            head -10 | sed 's/^/    /'
    else
        echo "antismash_run.log: clean (no WARNING/ERROR/Skipping entries)"
    fi
else
    echo "Note: antismash_run.log not found or empty at ${antismash_log}"
fi

# 5) Disk footprint of this sample's output (useful for capacity planning)
echo
echo "Output footprint: $(du -sh "${OUT_DIR}" 2>/dev/null | cut -f1)"

echo "=========================================="
