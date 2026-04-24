#!/usr/bin/env bash
set -euo pipefail

#SBATCH -A silage_microbiome
#SBATCH -N 1
#SBATCH -n 8
#SBATCH --mem=40G
#SBATCH -p ceres
#SBATCH -t 1:00:00
#SBATCH --job-name=busco_assembly_eval
#SBATCH --array=1-9
#SBATCH --output=/dev/null

# Resolve project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Load paths
source "${PROJECT_ROOT}/config/paths.sh"

module load busco5

MANIFEST="${PROJECT_ROOT}/scripts/sample_manifest.tsv"

# Skip header and read sample_id + R1_path
tail -n +2 "$MANIFEST" | while IFS=$'\t' read -r sample_id timepoint replicate R1_path; do
    
    echo "Running NanoPlot for: $sample_id"
    
    # Create sample-level QC directory
    sample_dir="${BUSCO_DIR}/${sample_id}"
    mkdir -p "$sample_dir"


    ##############################
    # 1) Busco Eval
    ##############################
    busco \
        --in "$" \
        --out "$nanoplot_dir" \
        --lineage hypocreales \
        --mode genome \
        -c 8 \
        --offline 
done
