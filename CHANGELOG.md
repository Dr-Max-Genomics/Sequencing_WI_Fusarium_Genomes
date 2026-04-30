# Changelog

<!-- ================================================================
  HOW TO USE THIS FILE
  - Record every meaningful change to the pipeline here: parameter
    tweaks, tool swaps, script edits, workflow changes, or lessons
    learned that affect how future batches should be run
  - Add new entries at the TOP under the current version heading
  - Follow semantic versioning:
      v1.x = parameter or workflow tweaks (no structural change)
      v2.0 = major structural change (new tool, new stage, new format)
  - Commit alongside the script or config file that changed:
      git add CHANGELOG.md config/paths.sh scripts/
      git commit -m "refactor: manifest-driven arrays — see CHANGELOG v1.4"
  - Cross-reference PROGRESS.md session entries where relevant
================================================================ -->

---

## Unreleased — in progress

### Pending decisions
- [ ] S5 analyses (telomere search, CAZymes, BigScape) not yet run — document
      parameters and scripts when initiated
- [ ] antiSMASH version and exact flags not yet documented — fill in when confirmed
- [ ] wtdbg2 trial barcode and BUSCO score still unrecovered (see v1.1)
- [ ] Confirm whether `funannotate setup -u -w -d $DB` is required before annotate

---

## v1.4 — 2026-04-29 — Pipeline refactor: manifest-driven arrays, script rename, DB migration, paths.sh restructure

### What changed
- Scripts 07–09c renamed and refactored — see table below
- All annotation stages (07–09c) now driven by `batch{N}_manifest.tsv`
  instead of barlist.txt — enables per-sample metadata (species, assembly
  file, EarlGrey species name, funannotate name, protein evidence, antiSMASH file)
- DB paths migrated from `/90daydata/` (temporary) to `/project/` (permanent)
- `paths.sh` restructured: `PROJECT_ROOT` now set via environment variable
  with hardcoded fallback; `11c_FUN_Annotate_Result/` removed entirely
- `08_sort_earlgrey_mask.sh` combines three previously separate steps
  (funannotate sort, EarlGrey, funannotate mask) into one array job
- BUSCO now runs offline with local lineage dataset
- Confirmed and documented funannotate annotate output co-location behavior
  (see known behavior note below)
- Established test-then-full-array pattern: task 1 submitted alone first,
  then tasks 2–N submitted as a separate array after confirming success

### Script rename table

| Old name | New name | Type | Notes |
|----------|----------|------|-------|
| `busco_eval.sh` (various) | `07_busco_eval.sh` | New | Manifest-driven; offline mode |
| *(separate scripts)* | `08_sort_earlgrey_mask.sh` | New | Combines sort + EarlGrey + mask |
| `funannotate_predict*.sh` | `09a_FUN_predict.sh` | Renamed + refactored | Manifest-driven; species-aware BUSCO seed |
| `IPscan.sh` / `09_IPscan_annotate.sh` | `09b_IPScan.sh` | Renamed + fixed | CPUs via `${SLURM_NTASKS}`; #SBATCH header now respected |
| `10_FUN_annotate.sh` | `09c_FUN_annotate.sh` | Renamed + refactored | Manifest-driven; GFF3 skip-if-exists check |

### Manifest structure — batch1_manifest.tsv

Tab-separated, one row per sample, header row skipped (LINE_NUM = TASK_ID + 1):

```
barcode  sample_id  assembly_file  busco_name  earlgrey_species  funannotate_name  funannotate_species  protein_evidence_file  antismash_file
```

Location: `${BATCH_DIR}/batch1_manifest.tsv`
(i.e., `/90daydata/silage_microbiome/max_seq/batch1_all_barcodes/batch1_manifest.tsv`)

### DB path migration

| Variable | Old path | New path |
|----------|----------|----------|
| `FUNANNOTATE_DB` | `/90daydata/.../funannotate_db` | `${DB_ROOT}/funannotate_db` |
| `AUGUSTUS_CONFIG_PATH` | `/90daydata/.../augustus/config` | `${DB_ROOT}/augustus_config/config` |
| `EARLGREY_SIF` | *(various)* | `${PROJECT_ROOT}/Containers/earlgrey_dfam3.7_latest.sif` |
| `BUSCO_DOWNLOADS` | *(not tracked)* | `${DB_ROOT}/busco_downloads` |

Where:
- `PROJECT_ROOT=/project/silage_microbiome/max.chi/fusarium_sequencing`
- `DB_ROOT=${PROJECT_ROOT}/DB_Databases`

### paths.sh changes

| | Before | After |
|--|--------|-------|
| PROJECT_ROOT | Hardcoded string | `${PROJECT_ROOT:-/project/...}` (env var with fallback) |
| `11c_FUN_Annotate_Result/` | In directory list | **Removed** |
| `EARLGREY_DIR` | Not in paths.sh | Added: `${BATCH_DIR}/09_EarlGrey` |
| `MASK_DIR` | Not in paths.sh | Added: `${BATCH_DIR}/10_Mask` |
| `ANTISMASH_DIR` | Not tracked | Added: `${BATCH_DIR}/12a_AntiSMASH_gbk` |
| `PROTEIN_EVIDENCE_DIR` | Not tracked | Added: `${DB_ROOT}/protein_evidence` |

### SLURM parameters — new scripts

| Script | CPUs | Memory | Time | Array |
|--------|------|--------|------|-------|
| `07_busco_eval.sh` | 8 | 40 GB | 1 hr | 1–9 |
| `08_sort_earlgrey_mask.sh` | 20 | 40 GB | 6 hrs | 1–9 |
| `09a_FUN_predict.sh` | 20 | 80 GB | 1 day | 1–9 |
| `09b_IPScan.sh` | 32 | 64 GB | 6 hrs | 1–9 |
| `09c_FUN_annotate.sh` | 32 | 150 GB | 6 hrs | 1–9 |

### ✅ Confirmed — funannotate annotate output co-location (resolved from v1.3)

Decision made: **accept funannotate's default behavior**. Annotate outputs
(`annotate_misc/`, `annotate_results/`) are written alongside `predict_misc/`
and `predict_results/` inside `11a_FUN_Predict_Result/FunAnnotate_{sampleID}/`.

`11c_FUN_Annotate_Result/` has been removed from `paths.sh` and will no longer
be created. All downstream references should use `FUN_PREDICT_DIR`.

This is consistent with funannotate's design and avoids unnecessary file movement.

### Batch 1 run — 2026-04-29

| Stage | Script | Job array | Tasks | Outcome |
|-------|--------|-----------|-------|---------|
| BUSCO eval | 07 | 20579367 | 1–9 | ✅ All complete |
| Sort+EarlGrey+Mask | 08 | 20589974 | 1–9 | ✅ All complete |
| Funannotate predict | 09a | 20613158 (task 1), 20613258 (2–9) | 9 | ✅ All complete |
| InterProScan | 09b | 20618475 (task 1), 20619448 (2–9) | 9 | ✅ All complete |
| Funannotate annotate | 09c | 20619524 (task 1), 20620393 (2–9) | 9 | ✅ All complete |

---

## v1.3 — 2026-04-21 — IPRScan + funannotate annotate first run (batch_2025-Dec); paths.sh bug fix

### What changed
- InterProScan (`09b_IPScan.sh`) added as a formal stage between predict and annotate
- Funannotate annotate run successfully for batch_2025-Dec after resolving
  `APPTAINERENV_FUNANNOTATE_DB` path
- Fixed critical `BASH_SOURCE[0]` bug in `paths.sh` — SLURM copies script to
  `/var/spool/slurmd/` breaking dynamic PROJECT_ROOT resolution. Fixed by
  hardcoding PROJECT_ROOT (later improved to env-var-with-fallback in v1.4)

### IPRScan parameters (batch_2025-Dec)

| Parameter | Value |
|-----------|-------|
| Format | xml |
| CPU | 32 |
| Time | 6 hrs |
| Flags | -dp -pa -goterms -iprlookup |
| Cluster | Ceres |

### Fix — APPTAINERENV_FUNANNOTATE_DB path

Root cause of 04-20 funannotate annotate failure on barcode37:

| | Path | Status |
|--|------|--------|
| Path A ✅ | `.../11_FunAnnotate/DB_FunannotateDatabase/funannotate_db` | Correct |
| Path B ❌ | `.../11_FunAnnotate/BD_BuscoDatabase/DB_FunannotateDatabase/funannotate_db` | Both dirs exist; wrong one |

### ⚠️ Known behavior — funannotate annotate output location (resolved in v1.4)

Annotate outputs written to predict directory rather than `11c_FUN_Annotate_Result/`.
Decision to accept this behavior and remove `11c` documented in v1.4.

### Batch 2 runs — 2026-04-21

| Stage | Job array | Tasks | Outcome |
|-------|-----------|-------|---------|
| IPRScan | 20526945_1–10 | 10 | ✅ All complete |
| Funannotate annotate | 20535822_1–10 | 10 | ✅ All complete |

---

## v1.2 — Fall 2025 — batch_2025-Dec (barcodes 36–45)

### What changed
- Batch 2 run entirely with Flye; wtdbg2 not used
- antiSMASH added as a stage after Funannotate predict
- Both Ceres and Atlas used

### Parameters

| Parameter | Value | Notes |
|-----------|-------|-------|
| MIN_LEN (NanoFilt) | 500 bp | Same as batch 1 |
| Assembler | Flye | wtdbg2 dropped |
| Flye --genome-size | 50m | |
| Flye --asm-coverage | 100 | |
| BUSCO lineage | hypocreales | |
| antiSMASH | Added | ⚠️ version + flags not yet documented |

### Results
- BUSCO range: 99.3–99.4% (hypocreales) — highest scores to date
- All 10 isolates through predict + antiSMASH
- IPRScan + annotate completed 2026-04-21 (v1.3)

### Clusters used
- Ceres: preprocessing, assembly, BUSCO, annotation
- Atlas: ⚠️ fill in which stages

---

## v1.1 — Spring 2025 — batch_2025-Feb (barcodes 49–53, 55–58)

### What changed
- Pipeline standardized 2025-02-14 after late 2024 troubleshooting
- wtdbg2 trialed on one barcode; Flye selected as standard
- All final assemblies produced with Flye

### Assembler evaluation — wtdbg2 vs Flye

| Criterion | wtdbg2 | Flye | Decision |
|-----------|--------|------|----------|
| Assembly quality | Lower contiguity | Higher contiguity | Flye preferred |
| BUSCO completeness | ⚠️ score not recorded | >99.1% | Flye preferred |
| Runtime | ⚠️ fill in | ~58 min @ 40 threads | — |
| Ease of use | Manual polish steps | Single sbatch | Flye preferred |

> ⚠️ Specific barcode trialed with wtdbg2 not recorded. Check Ceres for
> `prefix.ctg.fa` or wtdbg2 logs to recover barcode ID and BUSCO score.

### Parameters

| Parameter | Value | Notes |
|-----------|-------|-------|
| MIN_LEN (NanoFilt) | 500 bp | Initial baseline |
| Assembler | Flye (final) | wtdbg2 trialed only |
| Flye --genome-size | 50m | |
| Flye --asm-coverage | 100 | |
| Flye --iterations | 1 | ⚠️ Confirm if intentional |
| BUSCO lineage (eval) | hypocreales | |
| BUSCO lineage (training) | sordariomycetes_odb10 | For Funannotate |
| Threads | 70 (S1) / 40 (Flye) / 20 (Funannotate) | |
| MEM_HIGH | 900,000 MB | |
| MEM_MED | 300,000 MB | |

### Results
- 9 isolates (barcode54 absent — not sequenced)
- BUSCO range: 99.1–99.3% (hypocreales)
- All through predict + antiSMASH; IPRScan + annotate completed 2026-04-29 (v1.4)

### Known issues
- Porechop / miniconda module conflict — see README.md §11

---

## v1.0 — Late 2024 — Initial pipeline development

### What this version represents
- Exploratory / troubleshooting phase
- Scripts tested on individual barcodes before batch processing
- Workflow originally in Rmd bash chunks — migrated to `.sh` scripts early 2025
- Legacy scripts preserved in `Atlas Scripts in sequencing pipeline/`

### Tools set up during this period
- Conda env `seqenv` created on Ceres
- Porechop, NanoFilt, NanoPlot, seqkit confirmed working
- Flye and wtdbg2 installed and tested
- Funannotate DB, Augustus config, BUSCO lineages, EarlGrey SIF obtained

---

## Parameter quick-reference — current defaults

> Always check `config/paths.sh` as the authoritative source.

| Parameter | Current value | Set in version |
|-----------|--------------|----------------|
| MIN_LEN | 500 bp | v1.0 |
| Assembler | Flye | v1.1 |
| Flye --genome-size | 50m | v1.1 |
| Flye --asm-coverage | 100 | v1.1 |
| BUSCO lineage (eval) | hypocreales_odb10 | v1.1 |
| BUSCO lineage (training) | sordariomycetes_odb10 | v1.1 |
| BUSCO mode | offline | v1.4 |
| THREADS (S1) | 70 | v1.0 |
| MEM_HIGH | 900,000 MB | v1.0 |
| IPRScan CPU | 32 via `${SLURM_NTASKS}` | v1.4 |
| FUNANNOTATE_DB | `${DB_ROOT}/funannotate_db` | v1.4 |
| AUGUSTUS_CONFIG_PATH | `${DB_ROOT}/augustus_config/config` | v1.4 |
| EARLGREY_SIF | `${PROJECT_ROOT}/Containers/earlgrey_dfam3.7_latest.sif` | v1.4 |
| Annotate output location | Co-located in `11a_FUN_Predict_Result/` | v1.4 |

---

_This file is version-controlled. Do not delete old entries._
