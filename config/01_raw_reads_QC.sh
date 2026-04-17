#!/usr/bin/env bash
set -euo pipefail

# Resolve project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Load paths
source "${PROJECT_ROOT}/config/paths.sh"

module load miniconda
source activate seq_env

MANIFEST="${PROJECT_ROOT}/scripts/sample_manifest.tsv"

# Skip header and read sample_id + R1_path
tail -n +2 "$MANIFEST" | while IFS=$'\t' read -r sample_id timepoint replicate R1_path; do
    
    echo "Running NanoPlot for: $sample_id"
    
    # Create sample-level QC directory
    sample_dir="${QC_DIR}/${sample_id}"
    mkdir -p "$sample_dir"

    # Subdirectories for each QC tool
    nanoplot_dir="${sample_dir}/nanoplot"
    nanostat_dir="${sample_dir}/nanostat"
    mkdir -p "$nanoplot_dir" "$nanostat_dir"



    ##############################
    # 1) NanoPlot QC
    ##############################
    NanoPlot \
        --fastq "$R1_path" \
        --outdir "$nanoplot_dir" \
        --prefix "${sample_id}_" \
        --threads 40 \
        --loglength \
        --plots dot \
        --tsv_stats \
        --N50

    ##############################
    # 2) NanoStat QC
    ##############################
    NanoStat \
        --fastq "$R1_path" \
	--threads 4 \
	--tsv \
        --outdir "$nanostat_dir" \
        --name "${sample_id}_nanostat"

done
