#!/usr/bin/env bash
set -euo pipefail

# Resolve project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Load paths
source "${PROJECT_ROOT}/config/paths.sh"

MANIFEST="${PROJECT_ROOT}/scripts/sample_manifest.tsv"

# Loop through manifest (skip header)
tail -n +2 "$MANIFEST" | while IFS=$'\t' read -r sample_id timepoint replicate R1_path; do

    echo "=== Running Porechop for sample: $sample_id ==="

    # Output directories
    sample_filtered="${FILTERED_DIR}/${sample_id}"
    porechop_dir="${sample_filtered}/porechop"
    mkdir -p "$porechop_dir"

    # Load Porechop environment
    module purge
    module load funannotate

    # Run Porechop

   # Funannotate is a pipeline for annotating eukaryotic genomes. It automates masking, gene prediction, and functional annotation.
   # **Prerequisites: Environment Setup**
   # Annotation requires specific environment variables to be set.

   # Set the path to the Funannotate database.

   export APPTAINERENV_FUNANNOTATE_DB=/90daydata/silage_microbiome/max_seq/batch1_all_barcodes/11_FunAnnotate/DB_FunannotateDatabase/funannotate_db

# Set the path for AUGUSTUS (a gene predictor) configuration files.

export AUGUSTUS_CONFIG_PATH=/90daydata/silage_microbiome/max_seq/batch1_all_barcodes/11_FunAnnotate/augustus/config
    module unload porechop

    echo "=== Finished Porechop: $sample_id ==="

done
