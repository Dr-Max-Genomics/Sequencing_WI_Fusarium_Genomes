# Changelog

<!-- ================================================================
  HOW TO USE THIS FILE
  - Record every meaningful change to the pipeline here
  - Add new entries at the TOP
  - Semantic versioning: v1.x = param/workflow tweaks; v2.0 = major change
  - Commit alongside changed scripts/configs
================================================================ -->

---

## Unreleased — in progress

### Pending
- [ ] S5 CAZymes, antiSMASH docs not yet finalized
- [ ] batch_2026-May: S1 starting — update when concat complete
- [ ] Telomere search for batch_2025-Dec pending (array script ready)
- [ ] antiSMASH version and exact flags not yet documented
- [ ] wtdbg2 trial barcode and BUSCO score still unrecovered (see v1.1)
- [ ] Verify barcode52 BUSCO score (inferred 99.3%)
- [ ] Confirm _F. annulatum_ protein evidence file exists in PROTEIN_EVIDENCE_DIR

---

## v1.5 — 2026-05-27 — Telomere search added; 01_concat.sh written; batch_2026-May initiated; barlist.txt deprecated; sample_id format standardized

### What changed
- `telomere_density.py` updated with graceful Bio/matplotlib import error
  handling, `--min-contig` filter, `matplotlib.use("Agg")` for HPC
  compatibility, and improved per-contig progress logging
- `10_telomere_search.sh` written — SLURM array wrapper with correct
  conda activation pattern that fixes the Bio import failure on batch nodes
- `01_concat.sh` written — manifest-driven array job for MinKNOW-basecalled
  barcode concatenation; replaces manual `cat *.fastq.gz > barcode.fastq.gz`
- batch_2026-May initiated: 7 isolates, barcode01/02/04–08
- `batch3_manifest.tsv` created
- **Standardized `sample_id` format to `Fus_BarXX`** (with underscore) across
  all batches and downstream artifacts — matches naming used during batch 1
- **Deprecated `barlist.txt`** in favor of manifest as single source of truth

### sample_id naming standard

| Component | Format | Example |
|-----------|--------|---------|
| `sample_id` | `Fus_Bar{NN}` | `Fus_Bar49`, `Fus_Bar01` |
| `assembly_file` | `{sample_id}_polished.fasta` | `Fus_Bar49_polished.fasta` |
| `busco_name` | `{sample_id}_busco` | `Fus_Bar49_busco` |
| `earlgrey_species` | `{sample_id}` | `Fus_Bar49` |
| `funannotate_name` | `FunAnnotate_{sample_id}` | `FunAnnotate_Fus_Bar49` |
| `antismash_file` | `{sample_id}.scaffolds_antiSMASH.gbk` | `Fus_Bar49.scaffolds_antiSMASH.gbk` |

Going forward, all new manifests use this convention. Existing batch 1 and 2
files on disk may have legacy variants (e.g., `FusBar36_new.proteins.fa`) —
these are not retroactively renamed but new artifacts follow the standard.

### `barlist.txt` deprecation

`barlist.txt` (one barcode per line, no metadata) was used by the original
preprocessing scripts (`02–05`) in `while read in; do ...; done < barlist.txt`
loops. With the v1.4 manifest architecture for stages 07–09c and the new
`01_concat.sh` (v1.5), the manifest's `barcode` column replaces all uses of
`barlist.txt`.

**Decision:** New batches use only `batch{N}_manifest.tsv`. Single source of
truth per batch. No separate barlist.

Existing batch 1 and 2 directories retain their `barlist.txt` files for the
legacy 02–05 scripts; future refactor of those scripts will fully retire it.

### Root cause — Bio import failure on batch nodes

Running `module load miniconda` in a batch script does NOT activate the
conda environment. `python` resolves to the system Python which has no
Biopython. Fix applied in `10_telomere_search.sh`:

```bash
# WRONG — module load alone is insufficient
module load miniconda

# CORRECT — must also init conda and activate env
module load miniconda
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate seqenv
```

This pattern should be used in any script that calls Python tools
installed in the conda environment.

### New scripts

| Script | Purpose | Stage |
|--------|---------|-------|
| `scripts/telomere_density.py` | Compute telomeric motif density per contig | S5.1 |
| `scripts/10_telomere_search.sh` | SLURM array wrapper for telomere_density.py | S5.1 |
| `scripts/01_concat.sh` | Concatenate MinKNOW barcode fastq.gz files | S1.1 |

### 01_concat.sh details

| Parameter | Value |
|-----------|-------|
| Input | `${RAW_DIR}/{barcode}/*.fastq.gz` |
| Output | `${RAW_DIR}/{barcode}/{barcode}.fastq.gz` |
| CPUs | 4 |
| Memory | 20 GB |
| Time | 2 hrs |
| Array | 1–7 (batch_2026-May); adjust `--array` flag per batch |
| Skip logic | Skips if output already exists and is non-empty |
| Manifest | `batch3_manifest.tsv` |

### 10_telomere_search.sh details

| Parameter | Value |
|-----------|-------|
| Window | 10,000 bp |
| Step | 1,000 bp |
| Min contig | 5,000 bp (skips tiny contigs) |
| Output TSV | `13_Telomere/{sample_id}/{sample_id}_telomere_density.tsv` |
| Output plots | `13_Telomere/{sample_id}/plots/{contig}.png` |
| CPUs | 4 |
| Memory | 16 GB |
| Time | 2 hrs |

### batch_2026-May isolates

| Barcode | Isolate ID | Species |
|---------|------------|---------|
| barcode01 | F-22-214.2 | _F. verticillioides_ |
| barcode02 | F-Arl-23.9 | _F. proliferatum_ |
| barcode04 | Fg-23-5.5 | _F. graminearum_ |
| barcode05 | F-23-1.1 | _F. annulatum_ ⚠️ new species — verify protein evidence |
| barcode06 | Fg-23-4.7 | _F. graminearum_ |
| barcode07 | Fg-23-1.5 | _F. graminearum_ |
| barcode08 | F-23-3 | _F. sporotrichioides_ |

> ⚠️ _F. annulatum_ (barcode05) is a new species not seen in previous batches.
> Confirm `Fannulatum_refseq.faa` exists in `${PROTEIN_EVIDENCE_DIR}` before
> running `09a_FUN_predict.sh`. Also confirm BUSCO seed species in the
> `case` statement in `09a_FUN_predict.sh` — add a new case if needed.

### Telomere search — batch_2025-Feb (2026-05-27)

Ran interactively (Bio import failure prevented batch submission — now fixed):

| Sample | Status | Output |
|--------|--------|--------|
| All 9 (barcode49–53, 55–58) | ✅ Complete | `13_Telomere/{sample_id}/` |

---

## v1.4 — 2026-04-29 — Manifest-driven arrays; script rename; DB migration; paths.sh restructure

### Script renames

| Old | New | Notes |
|-----|-----|-------|
| Various | `07_busco_eval.sh` | New; manifest-driven; offline mode |
| Separate scripts | `08_sort_earlgrey_mask.sh` | New; combines sort + EarlGrey + mask |
| `funannotate_predict*.sh` | `09a_FUN_predict.sh` | Renamed + species-aware BUSCO seed |
| `IPscan.sh` | `09b_IPScan.sh` | Renamed; CPUs via `${SLURM_NTASKS}` |
| `10_FUN_annotate.sh` | `09c_FUN_annotate.sh` | Renamed + manifest-driven |

### DB path migration

| Variable | Old | New |
|----------|-----|-----|
| `FUNANNOTATE_DB` | `/90daydata/...` | `${DB_ROOT}/funannotate_db` |
| `AUGUSTUS_CONFIG_PATH` | `/90daydata/...` | `${DB_ROOT}/augustus_config/config` |
| `EARLGREY_SIF` | Various | `${PROJECT_ROOT}/Containers/earlgrey_dfam3.7_latest.sif` |
| `BUSCO_DOWNLOADS` | Not tracked | `${DB_ROOT}/busco_downloads` |

### ✅ Resolved — funannotate annotate output co-location

`11c_FUN_Annotate_Result/` removed from paths.sh. Annotate outputs land in
`11a_FUN_Predict_Result/FunAnnotate_{sampleID}/` alongside predict outputs.
This is funannotate's expected behavior.

### Batch 1 run — 2026-04-29

| Stage | Job array | Outcome |
|-------|-----------|---------|
| BUSCO eval | 20579367_1–9 | ✅ |
| Sort+EarlGrey+Mask | 20589974_1–9 | ✅ |
| Funannotate predict | 20613158_1, 20613258_2–9 | ✅ |
| InterProScan | 20618475_1, 20619448_2–9 | ✅ |
| Funannotate annotate | 20619524_1, 20620393_2–9 | ✅ |

---

## v1.3 — 2026-04-21 — IPRScan + funannotate annotate (batch_2025-Dec); paths.sh bug fix

- Fixed `BASH_SOURCE[0]` PROJECT_ROOT resolution failure under sbatch
- `APPTAINERENV_FUNANNOTATE_DB` path confirmed (Path A)
- batch_2025-Dec IPRScan: job 20526945_1–10 ✅
- batch_2025-Dec annotate: job 20535822_1–10 ✅

---

## v1.2 — Fall 2025 — batch_2025-Dec (barcode36–45)

- Flye only (wtdbg2 dropped)
- antiSMASH added as post-predict stage
- BUSCO range: 99.3–99.4% (hypocreales)

---

## v1.1 — Spring 2025 — batch_2025-Feb (barcode49–53, 55–58)

- Pipeline standardized 2025-02-14
- wtdbg2 trialed on one barcode; Flye selected as standard
- BUSCO range: 99.1–99.3% (hypocreales)
- Known issue: Porechop/miniconda conflict — see README §12

---

## v1.0 — Late 2024 — Initial development

- Scripts migrated from Rmd bash chunks to `.sh` files
- Conda env `seqenv` set up; tools confirmed working
- Legacy scripts in `Atlas Scripts in sequencing pipeline/`

---

## Parameter quick-reference — current defaults

| Parameter | Value | Set in |
|-----------|-------|--------|
| MIN_LEN | 500 bp | v1.0 |
| Assembler | Flye | v1.1 |
| Flye --genome-size | 50m | v1.1 |
| Flye --asm-coverage | 100 | v1.1 |
| BUSCO lineage (eval) | hypocreales_odb10 | v1.1 |
| BUSCO lineage (training) | sordariomycetes_odb10 | v1.1 |
| BUSCO mode | offline | v1.4 |
| IPRScan CPU | 32 via `${SLURM_NTASKS}` | v1.4 |
| FUNANNOTATE_DB | `${DB_ROOT}/funannotate_db` | v1.4 |
| Telomere window | 10,000 bp | v1.5 |
| Telomere step | 1,000 bp | v1.5 |
| Telomere min-contig | 5,000 bp | v1.5 |

---

_This file is version-controlled. Do not delete old entries._
