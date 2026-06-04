#!/usr/bin/env bash

# -------------------------------
# Project + Batch Configuration
# -------------------------------

PROJECT_ROOT="${PROJECT_ROOT:-/project/silage_microbiome/max.chi/fusarium_sequencing}"

# Set this once per batch — must match the manifest filename:
#   ${PROJECT_ROOT}/config/manifests/${BATCH_ID}_manifest.tsv
BATCH_ID="batch2_2025-Dec"

SCRATCH_ROOT="/90daydata/silage_microbiome/max_seq"

BATCH_DIR="${SCRATCH_ROOT}/${BATCH_ID}"

# -------------------------------
# Containers
# -------------------------------
EARLGREY_SIF="${PROJECT_ROOT}/Containers/earlgrey_dfam3.7_latest.sif"

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
BUSCO_DIR="${BATCH_DIR}/08_Busco_Evaluation"
EARLGREY_DIR="${BATCH_DIR}/09_EarlGrey"
MASK_DIR="${BATCH_DIR}/10_Mask"

# Funannotate / annotation steps
DB_ROOT="${PROJECT_ROOT}/DB_Databases"
BUSCO_DOWNLOADS="${DB_ROOT}/busco_downloads"
FUN_PREDICT_DIR="${BATCH_DIR}/11a_FUN_Predict_Result"    # input from predict
INTERPROSCAN_DIR="${BATCH_DIR}/11b_InterProScan"         # global IP outputs
ANTISMASH_DIR="${BATCH_DIR}/12a_AntiSMASH_gbk"           # antismash gbk output folder
# Annotate outputs live inside FUN_PREDICT_DIR per isolate (see CHANGELOG v1.4)

# S5 — Genome-wide analyses
TELOMERE_DIR="${BATCH_DIR}/12b_Telomere"

# Funannotate DB + Augustus config
AUGUSTUS_CONFIG_PATH="${DB_ROOT}/augustus_config/config"
PROTEIN_EVIDENCE_DIR="${DB_ROOT}/protein_evidence"

# -------------------------------
# Manifest — single source of truth for sample metadata
# Lives in the GIT REPO (canonical), not on scratch — survives /90daydata purges,
# version-controlled, visible to collaborators on GitHub.
# A symlink at ${BATCH_DIR}/manifest.tsv points back to this file for convenience
# when browsing data on Ceres — see CHANGELOG v1.6.
# -------------------------------
MANIFEST="${PROJECT_ROOT}/config/manifests/${BATCH_ID}_manifest.tsv"

# -------------------------------
# Logs
# -------------------------------
LOG_DIR="${BATCH_DIR}/logs"

# -------------------------------
# Scripts directory
# -------------------------------
SCRIPTS_DIR="${PROJECT_ROOT}/scripts"

# -------------------------------
# Ensure batch directories exist
# -------------------------------
mkdir -p \
  "$RAW_DIR" "$QC_DIR" "$TRIM_DIR" "$TRIMMED_DIR" "$SUMMARY_DIR" \
  "$ASSEMBLY_DIR" "$POLISH_DIR" "$POLISHED_DIR" "$BUSCO_DIR" \
  "$FUN_PREDICT_DIR" "$INTERPROSCAN_DIR" "$ANTISMASH_DIR" "$LOG_DIR" \
  "$DB_ROOT" "$BUSCO_DOWNLOADS" "$EARLGREY_DIR" "$MASK_DIR" \
  "$TELOMERE_DIR"
