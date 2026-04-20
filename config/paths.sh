#!/usr/bin/env bash

# -------------------------------
# Project + Batch Configuration
# -------------------------------

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Set this once per batch
BATCH_ID="jan_batch2_all_barcodes"

SCRATCH_ROOT="/90daydata/silage_microbiome/max_seq"

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

# Funannotate / annotation steps
FUN_DB_DIR="${BATCH_DIR}/11_FunAnnotate"                 # DB + augustus etc.
FUN_PREDICT_DIR="${BATCH_DIR}/11a_FUN_Predict_Result"    # input from predict
INTERPROSCAN_DIR="${BATCH_DIR}/11b_InterProScan"         # global IP outputs
FUN_ANNOTATE_DIR="${BATCH_DIR}/11c_FUN_Annotate_Result"  # annotate outputs

# Funannotate DB + Augustus config
FUNANNOTATE_DB_PATH="${FUN_DB_DIR}/DB_FunannotateDatabase/funannotate_db"
AUGUSTUS_CONFIG_PATH="${FUN_DB_DIR}/augustus/config"

# Logs
LOG_DIR="${BATCH_DIR}/logs"

# Scripts directory
SCRIPTS_DIR="${PROJECT_ROOT}/scripts"

# Ensure batch directories exist
mkdir -p \
  "$RAW_DIR" "$QC_DIR" "$TRIM_DIR" "$TRIMMED_DIR" "$SUMMARY_DIR" \
  "$ASSEMBLY_DIR" "$POLISH_DIR" "$POLISHED_DIR" "$BUSCO_DIR" \
  "$FUN_DB_DIR" "$FUN_PREDICT_DIR" "$INTERPROSCAN_DIR" "$FUN_ANNOTATE_DIR" \
  "$LOG_DIR"

