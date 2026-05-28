#!/usr/bin/env bash
# -----------------------------------------------------------------------
# migrate_manifests_to_repo.sh
# Purpose: One-time migration to move manifests from scratch to the Git
#          repo (canonical location) and create convenience symlinks on
#          scratch. Run from your repo root on Ceres.
# Date:    2026-05-27
# Related: CHANGELOG.md v1.6
#
# Usage:   bash migrate_manifests_to_repo.sh
#          (or copy-paste the commands one block at a time)
# -----------------------------------------------------------------------

set -euo pipefail

# -- 0. Set repo root --
REPO_ROOT="/project/silage_microbiome/max.chi/fusarium_sequencing"
cd "${REPO_ROOT}"

# -- 1. Create manifests directory in repo --
mkdir -p config/manifests

# -- 2. Copy existing manifests from scratch to repo --

# batch_2025-Feb
SRC1="/90daydata/silage_microbiome/max_seq/batch1_all_barcodes/batch1_manifest.tsv"
DST1="${REPO_ROOT}/config/manifests/batch_2025-Feb_manifest.tsv"
if [[ -f "$SRC1" ]]; then
    cp "$SRC1" "$DST1"
    echo "Copied: $SRC1 → $DST1"
else
    echo "WARN: $SRC1 not found — skipping"
fi

# batch_2025-Dec
SRC2="/90daydata/silage_microbiome/max_seq/jan_batch2_all_barcodes/batch2_manifest.tsv"
DST2="${REPO_ROOT}/config/manifests/batch_2025-Dec_manifest.tsv"
if [[ -f "$SRC2" ]]; then
    cp "$SRC2" "$DST2"
    echo "Copied: $SRC2 → $DST2"
else
    echo "WARN: $SRC2 not found — adjust path if your batch 2 manifest filename differs"
fi

# batch_2026-May — should already exist in the repo from this conversation
# Just confirm:
if [[ -f "${REPO_ROOT}/config/manifests/batch_2026-May_manifest.tsv" ]]; then
    echo "OK: batch_2026-May_manifest.tsv already in place"
else
    echo "WARN: batch_2026-May_manifest.tsv missing — add it before running batch 3"
fi

# -- 3. Create convenience symlinks on scratch (best-of-both-worlds) --
# These let you 'ls' the batch directory on Ceres and still see the manifest
# alongside the data. Scripts don't depend on these — they read MANIFEST
# from paths.sh — but they're convenient when poking around.

mkdir -p /90daydata/silage_microbiome/max_seq/batch1_all_barcodes
ln -sfn "${REPO_ROOT}/config/manifests/batch_2025-Feb_manifest.tsv" \
        /90daydata/silage_microbiome/max_seq/batch1_all_barcodes/manifest.tsv

mkdir -p /90daydata/silage_microbiome/max_seq/jan_batch2_all_barcodes
ln -sfn "${REPO_ROOT}/config/manifests/batch_2025-Dec_manifest.tsv" \
        /90daydata/silage_microbiome/max_seq/jan_batch2_all_barcodes/manifest.tsv

mkdir -p /90daydata/silage_microbiome/max_seq/batch_2026-May
ln -sfn "${REPO_ROOT}/config/manifests/batch_2026-May_manifest.tsv" \
        /90daydata/silage_microbiome/max_seq/batch_2026-May/manifest.tsv

echo "Symlinks created on scratch."

# -- 4. Verify --
echo
echo "--- Verification ---"
ls -lh "${REPO_ROOT}/config/manifests/"
echo
echo "Symlinks on scratch:"
ls -la /90daydata/silage_microbiome/max_seq/*/manifest.tsv 2>/dev/null || true

# -- 5. Commit to Git --
echo
echo "--- Next steps ---"
cat <<EOF
1. Commit the manifests to Git:
     cd ${REPO_ROOT}
     git add config/manifests/ paths.sh scripts/
     git commit -m "v1.6: move manifests to repo; symlinks on scratch"
     git push

2. Old manifest files on scratch can stay (harmless) or be removed:
     rm /90daydata/silage_microbiome/max_seq/batch1_all_barcodes/batch1_manifest.tsv

3. For any new batch going forward:
     a) Set BATCH_ID in config/paths.sh
     b) Create config/manifests/\${BATCH_ID}_manifest.tsv
     c) Create symlink on scratch (optional):
          ln -sfn \${PROJECT_ROOT}/config/manifests/\${BATCH_ID}_manifest.tsv \\
                  \${BATCH_DIR}/manifest.tsv
EOF
