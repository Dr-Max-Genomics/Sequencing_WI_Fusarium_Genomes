#!/usr/bin/env bash
#SBATCH -A silage_microbiome
#SBATCH -N 1
#SBATCH -n 8
#SBATCH --mem=32G
#SBATCH -p ceres
#SBATCH -t 01:00:00
#SBATCH --job-name=13b_cazyme_summary
#SBATCH --output=/dev/null

set -euo pipefail

###############################################################################
# 13b_Cazyme_summary.sh
# Purpose : Summarize dbCAN outputs from 13a into:
#   - cazyme_summary.tsv
#   - parsed/cazyme_profiles.tsv
#   - cazyme_diversity.tsv
# Output  : ${CAZYMES_DIR}/13b_Cazyme_summary/*
#
# CHANGELOG (this revision):
#   - get_proteins_faa(): guard `find` against a missing annotate_results dir
#     (e.g. deleted by a later concurrent funannotate job pointed at the same
#     output folder — see CHANGELOG history for the Fus_Bar01 incident).
#     Previously this `find` could exit 1 and, under `set -e`, kill the whole
#     summary job for every sample, not just the affected one.
#   - Manifest lookup: replaced the `read < <(get_meta ...)` process-substitution
#     pattern with an explicit variable check. If get_meta finds no match,
#     `read` hits EOF and returns 1, which is also fatal under `set -e`.
#   - Both failure modes now log a WARNING for the affected sample and continue
#     with degraded (zero/unknown) values, instead of aborting the entire run.
###############################################################################

PROJECT_ROOT="${PROJECT_ROOT:-/project/silage_microbiome/max.chi/fusarium_sequencing}"
# shellcheck disable=SC1091
source "${PROJECT_ROOT}/config/paths.sh"

# --------------- Directories (match 13a) ---------------
OUT_ROOT="${CAZYMES_DIR}"                          # all per-sample dbCAN output dirs
SUM_ROOT="${CAZYMES_DIR}/13b_Cazyme_summary"       # summary output
mkdir -p "${SUM_ROOT}/parsed" "${LOG_DIR}/cazymes"

LOG_FILE="${LOG_DIR}/cazymes/13b_cazyme_summary.log"
exec > "${LOG_FILE}" 2>&1

echo "[$(date)] Summarizing dbCAN outputs..."
echo "13a outputs root : ${OUT_ROOT}"
echo "Summary directory: ${SUM_ROOT}"
echo "Manifest         : ${MANIFEST}"
echo ""

CAZYME_COUNTS="${SUM_ROOT}/cazyme_summary.tsv"
CAZYME_PROFILES="${SUM_ROOT}/parsed/cazyme_profiles.tsv"
DIVERSITY="${SUM_ROOT}/cazyme_diversity.tsv"

printf "sample\tisolate\tspecies\ttotal_proteins\ttotal_cazymes\tcazyme_percent\tgh_count\tgt_count\tpl_count\tce_count\n" > "${CAZYME_COUNTS}"
printf "sample\tisolate\tspecies\tcazyme_id\tcazyme_family\tprotein_id\te_value\n" > "${CAZYME_PROFILES}"

# --------------- Helpers ---------------
find_overview() {
  local d="$1"
  for f in overview.txt overview_result.txt overview.tsv; do
    [[ -f "${d}/${f}" ]] && { echo "${d}/${f}"; return 0; }
  done
  echo ""
}

counts_from_overview() {
  local O="$1"
  local GH GT PL CE TOTAL
  GH=$(awk -F'\t' 'NR>1 && $2 ~ /^GH[0-9]+/ {c++} END{print c+0}' "${O}")
  GT=$(awk -F'\t' 'NR>1 && $2 ~ /^GT[0-9]+/ {c++} END{print c+0}' "${O}")
  PL=$(awk -F'\t' 'NR>1 && $2 ~ /^PL[0-9]+/ {c++} END{print c+0}' "${O}")
  CE=$(awk -F'\t' 'NR>1 && $2 ~ /^CE[0-9]+/ {c++} END{print c+0}' "${O}")
  TOTAL=$((GH + GT + PL + CE))
  printf "%s %s %s %s %s\n" "${TOTAL}" "${GH}" "${GT}" "${PL}" "${CE}"
}

profiles_from_overview() {
  local O="$1" sample="$2" isolate="$3" species="$4"
  awk -F'\t' -v OFS='\t' -v samp="${sample}" -v iso="${isolate}" -v sp="${species}" '
    NR>1 && $2 ~ /^(GH|GT|PL|CE)[0-9]+/ { print samp, iso, sp, NR-1, $2, $1, "NA" }
  ' "${O}" >> "${CAZYME_PROFILES}"
}

# Manifest lookup: sample -> species, isolate (9-col manifest)
# Prints "species\tisolate" (fields 7,6) on a match; prints nothing otherwise.
get_meta() {
  local sample="$1"
  awk -F'\t' -v s="${sample}" 'NR>1 && $2==s {print $7 "\t" $6; exit}' "${MANIFEST}"
}

# Proteins path for counts. Never lets a missing directory kill the script:
# `find` on a nonexistent path exits 1, which is fatal under `set -e` unless
# guarded here.
get_proteins_faa() {
  local isolate="$1"
  local dir="${FUN_PREDICT_DIR}/${isolate}/annotate_results"
  find "${dir}" -maxdepth 1 -type f -name "*.proteins.fa" -print -quit 2>/dev/null || true
}

# --------------- Iterate over 13a outputs ---------------
shopt -s nullglob
for d in "${OUT_ROOT}"/*; do
  [[ -d "${d}" ]] || continue

  # Skip the summary directory itself if it exists inside CAZYMES_DIR
  [[ "$(basename "${d}")" == "13b_Cazyme_summary" ]] && continue

  SAMPLE="$(basename "${d}")"

  # --- Manifest lookup (guarded: no match must not kill the script) ---
  META="$(get_meta "${SAMPLE}" || true)"
  if [[ -n "${META}" ]]; then
    IFS=$'\t' read -r SPECIES ISOLATE <<< "${META}"
  else
    echo "WARNING: [${SAMPLE}] no manifest match (column 2) in ${MANIFEST}; species/isolate set to 'unknown'"
    SPECIES=""
    ISOLATE=""
  fi
  SPECIES="${SPECIES:-unknown}"
  ISOLATE="${ISOLATE:-unknown}"

  # --- Proteome lookup (guarded: missing annotate_results dir must not kill the script) ---
  TOTAL_PROTEINS=0
  if [[ "${ISOLATE}" != "unknown" ]]; then
    PROTEOME="$(get_proteins_faa "${ISOLATE}")"
    if [[ -n "${PROTEOME}" && -s "${PROTEOME}" ]]; then
      TOTAL_PROTEINS=$(grep -c '^>' "${PROTEOME}" || echo "0")
    else
      echo "WARNING: [${SAMPLE}] no *.proteins.fa found under ${FUN_PREDICT_DIR}/${ISOLATE}/annotate_results (dir may be missing or was overwritten by a later job); total_proteins=0"
    fi
  fi

  # --- dbCAN overview lookup ---
  OVERVIEW="$(find_overview "${d}")"
  GH=0; GT=0; PL=0; CE=0; TOTAL_CAZYMES=0
  if [[ -n "${OVERVIEW}" ]]; then
    read -r TOTAL_CAZYMES GH GT PL CE < <(counts_from_overview "${OVERVIEW}")
    profiles_from_overview "${OVERVIEW}" "${SAMPLE}" "${ISOLATE}" "${SPECIES}"
  else
    echo "WARNING: [${SAMPLE}] no overview file found under ${d} (dbCAN may not have completed); cazyme counts=0"
  fi

  PCT=$(awk "BEGIN{if(${TOTAL_PROTEINS}>0) printf \"%.2f\", (${TOTAL_CAZYMES}/${TOTAL_PROTEINS})*100; else print \"0.00\"}")

  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "${SAMPLE}" "${ISOLATE}" "${SPECIES}" \
    "${TOTAL_PROTEINS}" "${TOTAL_CAZYMES}" "${PCT}" \
    "${GH}" "${GT}" "${PL}" "${CE}" \
    >> "${CAZYME_COUNTS}"
done
shopt -u nullglob

# --------------- Species diversity ---------------
printf "species\tmean_cazymes\tstd_cazymes\tmean_percent\tgh_mean\tgt_mean\tpl_mean\tce_mean\n" > "${DIVERSITY}"

awk -F'\t' 'NR>1 {print $3}' "${CAZYME_COUNTS}" | sort -u | while read -r sp; do
  [[ -z "${sp}" ]] && continue
  COUNTS=$(awk -F'\t' -v s="${sp}" '$3 == s {print $5}' "${CAZYME_COUNTS}")
  PERCENTS=$(awk -F'\t' -v s="${sp}" '$3 == s {print $6}' "${CAZYME_COUNTS}")
  GH_COUNTS=$(awk -F'\t' -v s="${sp}" '$3 == s {print $7}' "${CAZYME_COUNTS}")
  GT_COUNTS=$(awk -F'\t' -v s="${sp}" '$3 == s {print $8}' "${CAZYME_COUNTS}")
  PL_COUNTS=$(awk -F'\t' -v s="${sp}" '$3 == s {print $9}' "${CAZYME_COUNTS}")
  CE_COUNTS=$(awk -F'\t' -v s="${sp}" '$3 == s {print $10}' "${CAZYME_COUNTS}")

  MEAN_CAZ=$(echo "${COUNTS}"   | awk '{sum+=$1; n++} END{if(n>0) printf "%.1f", sum/n; else print "0.0"}')
  MEAN_PCT=$(echo "${PERCENTS}" | awk '{sum+=$1; n++} END{if(n>0) printf "%.2f", sum/n; else print "0.00"}')
  GH_MEAN=$(echo "${GH_COUNTS}" | awk '{sum+=$1; n++} END{if(n>0) printf "%.1f", sum/n; else print "0.0"}')
  GT_MEAN=$(echo "${GT_COUNTS}" | awk '{sum+=$1; n++} END{if(n>0) printf "%.1f", sum/n; else print "0.0"}')
  PL_MEAN=$(echo "${PL_COUNTS}" | awk '{sum+=$1; n++} END{if(n>0) printf "%.1f", sum/n; else print "0.0"}')
  CE_MEAN=$(echo "${CE_COUNTS}" | awk '{sum+=$1; n++} END{if(n>0) printf "%.1f", sum/n; else print "0.0"}')

  STD_CAZ=$(echo "${COUNTS}" | awk -v m="${MEAN_CAZ}" '
    {x[NR]=$1; n++}
    END{
      if(n<2){printf "%.1f", 0.0; exit}
      sumsq=0
      for(i=1;i<=n;i++){d=(x[i]-m); sumsq+=d*d}
      printf "%.1f", sqrt(sumsq/(n-1))
    }')

  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "${sp}" "${MEAN_CAZ}" "${STD_CAZ}" "${MEAN_PCT}" \
    "${GH_MEAN}" "${GT_MEAN}" "${PL_MEAN}" "${CE_MEAN}" \
    >> "${DIVERSITY}"
done

echo "✓ Summary:   ${CAZYME_COUNTS}"
echo "✓ Profiles:  ${CAZYME_PROFILES}"
echo "✓ Diversity: ${DIVERSITY}"
echo "[$(date)] Complete."
