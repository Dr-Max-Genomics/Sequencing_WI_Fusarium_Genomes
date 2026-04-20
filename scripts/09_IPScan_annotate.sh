#!/usr/bin/env bash

set -euo pipefail

# -------------------------------
# Setup
# -------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${PROJECT_ROOT}/config/paths.sh"



mkdir -p "${INTERPROSCAN_DIR}" "${LOG_DIR}/interproscan"



SAMPLE_LIST="${BATCH_DIR}/sample_list.txt"



# Generate sample list once if missing

if [[ ! -f "${SAMPLE_LIST}" ]]; then

  echo "Generating sample list at ${SAMPLE_LIST}" >&2

  : > "${SAMPLE_LIST}"

  for d in "${FUN_PREDICT_DIR}"/FunAnnotate_*; do

    [[ -d "$d" ]] || continue

    basename "$d"

  done | sort > "${SAMPLE_LIST}"

fi



# Get sample for this array task

if [[ -z "${SLURM_ARRAY_TASK_ID:-}" ]]; then

  echo "SLURM_ARRAY_TASK_ID is not set; run as an array job." >&2

  exit 1

fi



sample=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "${SAMPLE_LIST}" || true)

if [[ -z "${sample}" ]]; then

  echo "No sample found for SLURM_ARRAY_TASK_ID=${SLURM_ARRAY_TASK_ID}" >&2

  exit 0

fi



log_file="${LOG_DIR}/interproscan/${sample}.log"

exec >"${log_file}" 2>&1



echo "[$(date)] Starting InterProScan for sample: ${sample}"



protein_dir="${FUN_PREDICT_DIR}/${sample}/predict_results"

protein_fa=( "${protein_dir}"/*.proteins.fa )



if [[ ! -f "${protein_fa[0]}" ]]; then

  echo "ERROR: No *.proteins.fa found in ${protein_dir}" >&2

  exit 1

fi



input_fa="${protein_fa[0]}"

output_xml="${INTERPROSCAN_DIR}/${sample}.xml"



# Skip if already done

if [[ -s "${output_xml}" ]]; then

  echo "Output XML already exists and is non-empty: ${output_xml} — skipping."

  exit 0

fi



module load interproscan



echo "Input FASTA: ${input_fa}"

echo "Output XML:  ${output_xml}"



# Some interproscan builds use -o, others -b; you said lowercase command works.

interproscan.sh \

  -i "${input_fa}" \

  -f xml \

  -o "${output_xml}" \

  --cpu 32 \

  -dp -pa \

  -goterms -iprlookup



echo "[$(date)] Finished InterProScan for sample: ${sample}"

