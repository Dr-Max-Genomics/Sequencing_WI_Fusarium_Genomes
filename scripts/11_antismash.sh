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
# FLAGS MATCH YOUR WEB RUN (reconstructed from Bar56FusCer.json v8.0.0):
#   --taxon fungi           organism type
#   --cb-general            ClusterBlast: compare vs MIBiG reference clusters
#   --cc-mibig              ClusterCompare: detailed MIBiG comparison
#   --clusterhmmer          Pfam annotation on cluster regions only
#   --tigrfam               TIGRfam domain annotation
#   --pfam2go               Map Pfam domains to Gene Ontology terms
#   --rre                   RREFinder: detect RiPP recognition elements
# NOT run (not in your web results): --smcog-trees, --cb-subclusters,
#   --cb-knownclusters, --fullhmmer
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
ANNOTATE_DIR="${FUN_PREDICT_DIR}/${funannotate_name}/annotate_results"
INPUT_GBK=$(find "${ANNOTATE_DIR}" -maxdepth 1 -name "*.gbk" | head -1)

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
        gbk_out=$(find "${OUT_DIR}" -maxdepth 1 -name "*.gbk" | head -1)
        [[ -n "${gbk_out}" ]] && ln -sfn "${gbk_out}" "${GBK_LINK}"
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
    --cc-mibig \
    --clusterhmmer \
    --tigrfam \
    --pfam2go \
    --genefinding-tool none \
    --minlength 1000 \
    --rre \
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

echo
echo "[$(date)] Done: ${sample_id}"
echo "Results: ${OUT_DIR}"
echo "BGC regions: $(grep -c 'region' "${OUT_DIR}/${sample_id}.json" 2>/dev/null || echo 'see index.html')"
