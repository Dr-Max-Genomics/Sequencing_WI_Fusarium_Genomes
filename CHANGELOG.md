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
      git add CHANGELOG.md config/params.env
      git commit -m "config: bump NanoFilt MIN_LEN 500→800 — see CHANGELOG"
  - Cross-reference PROGRESS.md session entries where relevant
================================================================ -->

---

## v1.3 — 2026-04-21 — IPRScan added + paths.sh bug fix

### What changed
- InterProScan (`IPscan.sh`) added as a formal pipeline stage between
  Funannotate predict and Funannotate annotate
- Fixed critical `BASH_SOURCE[0]` bug in `config/paths.sh` — dynamic
  PROJECT_ROOT resolution fails under sbatch because SLURM copies the
  script to `/var/spool/slurmd/` before execution. Fixed by hardcoding
  PROJECT_ROOT in `paths.sh`

### New stage added

| Stage | Script | Position in pipeline |
|-------|--------|----------------------|
| InterProScan | `scripts/09_IPscan_annotate.sh` | Between S4 predict and S4 annotate |

### IPRScan parameters

| Parameter | Value |
|-----------|-------|
| Format | xml |
| CPU | 32 |
| Flags | -dp -pa -goterms -iprlookup |
| Execution mode | SLURM array (one task per sample) |
| time req | 6hrs |
| Cluster | Ceres |

### First run
- Batch: batch_2025-fall (barcode36–45)
- Job array: 20526945_1 through 20526945_10
- Date: 2026-04-21
- Outcome: All 10 tasks completed successfully

### Fix details — paths.sh PROJECT_ROOT
| | Before | After |
|--|--------|-------|
| PROJECT_ROOT | Derived via `BASH_SOURCE[0]` | Hardcoded: `/home/maxwell.chibuogwu/Sequencing_WI_Fusarium_Genomes` |
| Works interactively | ✅ | ✅ |
| Works under sbatch | ❌ | ✅ |

## Unreleased — in progress

### Pending decisions
- [ ] Downstream Funannotate annotation steps not yet run on either batch —
      update this file when those stages are finalized and parameters confirmed
- [ ] antiSMASH version and parameters not yet documented — add when confirmed
- [ ] Confirm exact wtdbg2 trial barcode and record BUSCO result (see v1.1 note)

---

## v1.2 — Fall 2025 — Batch 2 (barcodes 36–45)

### What changed
- Batch 2 run entirely with Flye; wtdbg2 not used
- antiSMASH secondary metabolite analysis added as a stage following
  Funannotate predict — not present in original batch 1 workflow
- Both Ceres and Atlas clusters used for this batch

### Parameters (batch_2025-fall)

| Parameter | Value | Notes |
|-----------|-------|-------|
| MIN_LEN (NanoFilt) | 500 bp | Same as batch 1 |
| Assembler | Flye | wtdbg2 dropped after batch 1 evaluation |
| Flye --genome-size | 50m | Same as batch 1 |
| Flye --asm-coverage | 100 | Same as batch 1 |
| BUSCO lineage | hypocreales | Same as batch 1 |
| Threads | 70 (preprocessing) / 40 (Flye) / 20 (Funannotate) | Same as batch 1 |
| MEM_HIGH | 900,000 MB | Same as batch 1 |
| antiSMASH | Added | Parameters — fill in version and flags used |

### Results summary
- All 10 isolates (barcode36–45) assembled and evaluated successfully
- BUSCO completeness range: 99.3–99.4% (hypocreales) — highest scores to date
- Gene prediction (Funannotate predict) complete on all 10 isolates
- antiSMASH complete on all 10 isolates
- Downstream Funannotate annotation steps pending

### Clusters used
- Ceres: preprocessing, assembly, BUSCO
- Atlas: [fill in which stages ran on Atlas]

---

## v1.1 — Spring 2025 — Batch 1 (barcodes 49–53, 55–58)

### What changed
- Pipeline formally standardized on 2025-02-14 after prior troubleshooting period
- wtdbg2 trialed as an alternative assembler on one barcode during this batch;
  Flye selected as the standard going forward due to superior assembly quality
- All final batch 1 assemblies produced with Flye

### Assembler evaluation — wtdbg2 vs Flye

| Criterion | wtdbg2 | Flye | Decision |
|-----------|--------|------|----------|
| Assembly quality | Lower contiguity observed | Higher contiguity | Flye preferred |
| BUSCO completeness | [score not recorded — fill in] | >99.1% all isolates | Flye preferred |
| Runtime | [fill in] | ~58 min per isolate at 40 threads | — |
| Ease of use on Ceres | Required manual polish steps | Single sbatch command | Flye preferred |

> ⚠️ The specific barcode trialed with wtdbg2 was not recorded. Locate the
> `prefix.ctg.fa` or wtdbg2 log files on Ceres to recover the barcode ID and
> BUSCO score, then update this table.

### Parameters (batch_2025-02)

| Parameter | Value | Notes |
|-----------|-------|-------|
| MIN_LEN (NanoFilt) | 500 bp | Initial baseline |
| Assembler | Flye (final) | wtdbg2 trialed, not used for final assemblies |
| Flye --genome-size | 50m | Based on expected Fusarium genome size |
| Flye --asm-coverage | 100 | Target 100× coverage |
| Flye --iterations | 1 | [note if this was intentional or default] |
| BUSCO lineage (assembly eval) | hypocreales | Primary lineage |
| BUSCO lineage (Augustus training) | sordariomycetes_odb10 | For Funannotate |
| Threads | 70 (preprocessing) / 40 (Flye) / 20 (Funannotate) | |
| MEM_HIGH | 900,000 MB | For dedup, Porechop, BUSCO |
| MEM_MED | 300,000 MB | For Flye assembly |

### Results summary
- 9 isolates processed (barcode54 absent — not sequenced this batch)
- BUSCO completeness range: 99.1–99.3% (hypocreales)
- All isolates through Funannotate predict and antiSMASH
- Downstream annotation steps in progress

### Known issues encountered
- Porechop / miniconda module conflict — resolved by unloading miniconda
  before loading Porechop. Documented in README.md §11.
- [Add any other issues encountered during this batch]

---

## v1.0 — Late 2024 — Initial pipeline development

### What this version represents
- Exploratory / troubleshooting phase prior to formal standardization
- Scripts tested on individual barcodes before batch processing
- Workflow originally documented as bash chunks in an Rmd file
- No formal parameter versioning at this stage

### Tools evaluated or configured during this period
- Conda environment `seqenv` created on Ceres
- Porechop, NanoFilt, NanoPlot, seqkit confirmed working
- Flye and wtdbg2 both installed and tested
- Funannotate database set up at `/project/silage_microbiome/max.chi/funannotate_db`
- Augustus config directory created with write permissions
- BUSCO lineage databases downloaded (hypocreales, sordariomycetes)
- EarlGrey Apptainer image (`earlgrey_dfam3.7_latest.sif`) obtained

### Notes
- Workflow migrated from Rmd bash chunks to standalone `.sh` scripts
  as part of pipeline formalization in early 2025
- Legacy scripts preserved in `Atlas Scripts in sequencing pipeline/`
  folder for reference

---

## Parameter quick-reference — current defaults

> Always check `config/params.env` as the authoritative source.
> This table is a summary only and may lag behind the file.

| Parameter | Current value | Set in version |
|-----------|--------------|----------------|
| MIN_LEN | 500 bp | v1.0 |
| Assembler | Flye | v1.1 |
| Flye --genome-size | 50m | v1.1 |
| Flye --asm-coverage | 100 | v1.1 |
| BUSCO lineage (eval) | hypocreales | v1.1 |
| BUSCO lineage (training) | sordariomycetes_odb10 | v1.1 |
| THREADS | 70 | v1.0 |
| MEM_HIGH | 900,000 MB | v1.0 |
| MEM_MED | 300,000 MB | v1.0 |
| antiSMASH | Added | v1.2 |

---

_This file is version-controlled. Do not delete old entries._
