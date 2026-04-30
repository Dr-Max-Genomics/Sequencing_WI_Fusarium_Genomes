#!/usr/bin/env bash
#SBATCH -A silage_microbiome
#SBATCH -N 1
#SBATCH -n 32
#SBATCH --mem=64G
#SBATCH -p ceres
#SBATCH -t 6:00:00
#SBATCH --job-name=iprscan
#SBATCH --array=1-9

set -euo pipefail

# -------------------------------
# Setup
# -------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="/project/silage_microbiome/max.chi/fusarium_sequencing"
source "${PROJECT_ROOT}/config/paths.sh"

mkdir -p "${INTERPROSCAN_DIR}" "${LOG_DIR}/interproscan"

# Pick the task's sample from manifest

MANIFEST="${BATCH_DIR}/batch1_manifest.tsv"
LINE_NUM=$((SLURM_ARRAY_TASK_ID + 1))
IFS=$'\t' read -r barcode sample_id assembly_file busco_name earlgrey_species \
    funannotate_name funannotate_species protein_evidence_file antismash_file \
    < <(sed -n "${LINE_NUM}p" "$MANIFEST")

#Per-sample log
log_file="${LOG_DIR}/interproscan/${sample_id}.log"
exec >"${log_file}" 2>&1

echo "[$(date)] Starting InterProScan for sample: ${sample_id}"

#Locate input proteins from predict output
protein_dir="${FUN_PREDICT_DIR}/${funannotate_name}/predict_results"
protein_fa=( "${protein_dir}"/*.proteins.fa )

if [[ ! -f "${protein_fa[0]}" ]]; then
  echo "ERROR: No *.proteins.fa found in ${protein_dir}" >&2
  exit 1
fi

input_fa="${protein_fa[0]}"
output_xml="${INTERPROSCAN_DIR}/${sample_id}.xml"

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
  --cpu "${SLURM_NTASKS}" \
  -dp -pa \
  -goterms -iprlookup

echo "[$(date)] Finished InterProScan for sample: ${sample_id}"
