#!/usr/bin/env bash

# -------------------------------
# Project + Batch Configuration
# -------------------------------

# Permanent project root (Git repo)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Set this once per batch
BATCH_ID="batch2_all_barcodes"

# Scratch root where all batches live
SCRATCH_ROOT="/90daydata/silage_microbiome/max_seq"

# Batch directory
BATCH_DIR="${SCRATCH_ROOT}/${BATCH_ID}"

# -------------------------------
# Standardized Step Directories
# -------------------------------

RAW_DIR="${BATCH_DIR}/00_Raw_Data"
QC_DIR="${BATCH_DIR}/01_QC"
TRIM_DIR="${BATCH_DIR}/02_Trimming"
TRIMMED_DIR="${BATCH_DIR}/03_Trimmed_Data"
SUMMARY_DIR="${BATCH_DIR}/04_Summary_Plots"
ASSEMBLY_DIR="${BATCH_DIR}/05_Genome_Assembly"
POLISH_DIR="${BATCH_DIR}/06_Alignment_Polishing"
POLISHED_DIR="${BATCH_DIR}/07_Polished_Genome"
BUSCO_DIR="${BATCH_DIR}/08_Busco_Analyses"
FUNANNOTATE_DIR="${BATCH_DIR}/11_FunAnnotate"
FUNANNOTATE_OUT="${BATCH_DIR}/11a_FunAnnotateOut"

# Scripts directory
SCRIPTS_DIR="${PROJECT_ROOT}/scripts"

# Ensure batch directories exist
mkdir -p \
    "$RAW_DIR" "$QC_DIR" "$TRIM_DIR" "$TRIMMED_DIR" "$SUMMARY_DIR" \
    "$ASSEMBLY_DIR" "$POLISH_DIR" "$POLISHED_DIR" "$BUSCO_DIR" \
    "$FUNANNOTATE_DIR" "$FUNANNOTATE_OUT"
