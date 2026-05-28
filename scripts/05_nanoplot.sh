#!/usr/bin/env bash
#SBATCH -A silage_microbiome
#SBATCH -N 1
#SBATCH -n 70
#SBATCH --mem=150G
#SBATCH -p ceres
#SBATCH -t 1-0
#SBATCH --job-name=nanoplot
#SBATCH --array=1-7
#SBATCH --output=/dev/null

set -euo pipefail

# -----------------------------------------------------------------------
# 05_nanoplot.sh
# Purpose : Generate per-sample QC plots and read statistics (NanoPlot)
#           on the FILTERED reads. Final Ceres S1 step.
#           S1 order: concat -> porechop -> dedup -> nanofilt -> nanoplot
# Usage   : sbatch --array=1 scripts/05_nanoplot.sh     # test one
#           sbatch --array=2-7 scripts/05_nanoplot.sh   # rest of batch
# Input   : 03_Trimmed_Data/{sample_id}.fastq   (from 04_nanofilt)
# Output  : 04_Summary_Plots/{sample_id}/       (HTML report + TSV stats)
# Env     : NanoPlot is in the seqenv conda environment.
# Note    : QC is run on FILTERED reads only. dorado correct outputs FASTA
#           (no quality scores), so post-correction NanoPlot would yield
#           only length metrics — not worth a separate stage. To check how
#           many reads HERRO retained, count records in the corrected FASTA:
#             grep -c "^>" corrected_reads/corrected_{sample_id}.fasta
# -----------------------------------------------------------------------

PROJECT_ROOT="${PROJECT_ROOT:-/project/silage_microbiome/max.chi/fusarium_sequencing}"
source "${PROJECT_ROOT}/config/paths.sh"

# -----------------------------------------------------------------------
# Conda activation (NanoPlot lives in seqenv)
# -----------------------------------------------------------------------
module load miniconda
source activate seqenv

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
INPUT="${TRIMMED_DIR}/${sample_id}.fastq"
OUTDIR="${SUMMARY_DIR}/${sample_id}"

mkdir -p "${OUTDIR}" "${LOG_DIR}/nanoplot"
log_file="${LOG_DIR}/nanoplot/${sample_id}.log"
exec >"${log_file}" 2>&1

echo "=========================================="
echo "[$(date)] NanoPlot QC"
echo "Barcode:  ${barcode}"
echo "Sample:   ${sample_id}"
echo "Input:    ${INPUT}"
echo "Output:   ${OUTDIR}"
echo "Manifest: ${MANIFEST}"
echo "Job ID:   ${SLURM_JOB_ID} / task ${SLURM_ARRAY_TASK_ID}"
echo "Host:     $(hostname)"
echo "=========================================="

# Validate input
if [[ ! -s "${INPUT}" ]]; then
    echo "ERROR: input not found or empty: ${INPUT}" >&2
    echo "Did 04_nanofilt.sh run successfully for ${sample_id}?" >&2
    exit 1
fi

# Skip if already done (report HTML present)
if compgen -G "${OUTDIR}/NanoPlot-report.html" > /dev/null; then
    echo "NanoPlot report already exists — skipping: ${OUTDIR}"
    exit 0
fi

# -----------------------------------------------------------------------
# Run NanoPlot
# -----------------------------------------------------------------------
echo "[$(date)] Running NanoPlot..."
NanoPlot \
    --fastq "${INPUT}" \
    --raw \
    --tsv_stats \
    --N50 \
    -o "${OUTDIR}"

echo "[$(date)] Done: ${sample_id} → ${OUTDIR}"
echo "Report: ${OUTDIR}/NanoPlot-report.html"
