# Pipeline progress log

<!-- ================================================================
  HOW TO USE THIS FILE
  - Add a new H2 entry (## YYYY-MM-DD — ...) at the TOP of the log
    for every work session, no matter how small
  - Commit after every session:
      git add PROGRESS.md && git commit -m "progress: <one-line summary>"
  - Use CTRL+F to search by barcode, cluster, stage, or job ID
  - For isolate-level status across all batches, see BATCHES.md
  - For pipeline/parameter version history, see CHANGELOG.md
================================================================ -->

---

## Session template — copy this block each time

```
## YYYY-MM-DD — [Ceres | Atlas] — Batch: [batch_YYYY-MM]

**Working directory:** /90daydata/silage_microbiome/[path]/
**Barcodes in scope:** barcode##, ##, ##

### What I ran
- Script / command:
- params.env version:
- Job IDs (sbatch):

### Outcome
- [ ] Completed successfully
- [ ] Completed with warnings (see notes)
- [ ] Failed — see notes

### Notes / observations
-

### Parameter changes from last session
| Parameter | Previous | This session | Reason |
|-----------|----------|--------------|--------|
|           |          |              |        |

### Next step
- Script / stage:
- Prep needed:
```

---

## Active project status

| Batch | Barcodes | Current stage | Cluster | Next action |
|-------|----------|--------------|---------|-------------|
| batch_2025-02 (Batch 1) | 49–53, 55–58 | 🟡 Downstream annotation in progress | Ceres | Complete remaining Funannotate steps |
| batch_2025-fall (Batch 2) | 36–45 | 🟡 Gene prediction + antiSMASH done | Ceres | Begin downstream annotation |

> Status key: 🟢 Complete · 🟡 In progress · 🔴 Blocked · ⚪ Not started

---

## Log entries
<!-- ─── Most recent entry at TOP ─────────────────────────── -->

```
## 2026-04-20 — [Ceres ] — Batch: [batch_2025-Dec]

**Working directory:** /90daydata/silage_microbiome/[path]/
**Barcodes in scope:** barcode36, 37, ##
```

### What I ran
- Script / command
```bash
ml purge 
ml interproscan
sbatch -A silage_microbiome -N 1 -n 80 -p ceres -t 1-00 --wrap="interproscan.sh -i bar36_predict_results/FusBar36_new.proteins.fa -f tsv,xml -dp --cpu 80 -goterms -iprlookup -pa"

#module purge before loading miniconda
#Running annotate without eggnog

a. export APPTAINERENV_FUNANNOTATE_DB=/90daydata/silage_microbiome/max_seq/jan_batch2_all_barcodes/11_FunAnnotate/DB_FunannotateDatabase/funannotate_db
a1? export APPTAINERENV_FUNANNOTATE_DB=/90daydata/silage_microbiome/max_seq/jan_batch2_all_barcodes/11_FunAnnotate/BD_BuscoDatabase/DB_FunannotateDatabase/funannotate_db

1. export AUGUSTUS_CONFIG_PATH=/90daydata/silage_microbiome/max_seq/jan_batch2_all_barcodes/11_FunAnnotate/augustus/config
2. funannotate setup -u -w -d $APPTAINERENV_FUNANNOTATE_DB #Maybe remove
sbatch -A silage_microbiome -N 1 -n 32 --mem=150GB -p ceres -t 6:00:00 --wrap="funannotate annotate -i Bar37_predict_results/ --iprscan FusBar37_IP.proteins.fa.xml --antismash FusBar37.scaffolds_antiSMASH.gbk --out bar37_annotate_results --cpus 32"

```
- params.env version: Running Interproscan on 4/18/26 - optimal 32 cores; 50GB mem at least 4hrs
- Job IDs (sbatch):

### Outcome
- [ ] Completed successfully
- [ ] Completed with warnings (see notes)
- [ ] Failed — see notes

### Notes / observations
-

### Parameter changes from last session
| Parameter | Previous | This session | Reason |
|-----------|----------|--------------|--------|
|           |          |              |        |

### Next step
- Script / stage:
- Prep needed:



---

## 2026-04-21 — Ceres — Batch: batch_2025-fall

**Working directory:** `/90daydata/silage_microbiome/max_seq/jan_batch2_all_barcodes/`
**Barcodes in scope:** barcode36–45 (all 10)

### What I ran
- Script: `scripts/09_/IPscan_annotate.sh`
- Submitted as SLURM array job: `sbatch --array=1-10 scripts/IPscan_annotate.sh`

### Outcome
- [x] Completed successfully — all 10 array tasks finished

### Notes / observations
- For some reason, slurm refused to read the `#SBATCH` flags in the script, so they were passed from the terminal after `ml interproscan`
- First use of IPscan.sh under the new repo structure
- Fixed BASH_SOURCE[0] / PROJECT_ROOT spool path bug before submission
  (hardcoded PROJECT_ROOT in config/paths.sh — see CHANGELOG.md v1.3)
- Output XML files written to: `11b_InterProScan/`

### Parameter changes from last session
| Parameter | Previous | This session | Reason |
|-----------|----------|--------------|--------|
| — | — | — | No parameter changes this session |

### Next step
- Script / stage: `funannotate annotate` (S4 downstream annotation) for batch_2025-fall
- Prep needed: Confirm all 10 XML files are non-empty before submitting annotate step


## 2025-02-14 — Pipeline formalized — Both batches context

**Note:** This entry reconstructs work completed prior to formal progress tracking.
Entries below summarize what is known about each batch as of the start of formal logging.
Going forward, add a new dated entry per session at the top of this section.

---

### Batch 1 retrospective (batch_2025-02) — barcodes 49–53, 55–58

**Cluster:** Ceres  
**Sequenced:** Spring 2025 (pipeline standardized 2025-02-14)  
**Working directory:** `/90daydata/silage_microbiome/max_seq/Max_pod_5s/isolate_fastq/sequence_cleanup/`

#### Stages completed (all barcodes unless noted)

| Stage | Status | Notes |
|-------|--------|-------|
| S1 — Concatenation | ✅ Done | cat *.fastq.gz → barcodeXX.fastq.gz |
| S1 — Deduplication | ✅ Done | seqkit rmdup; no duplicates found |
| S1 — Porechop | ✅ Done | porechop-runner.py -t 70 |
| S1 — NanoFilt | ✅ Done | -l 500 bp cutoff |
| S1 — NanoPlot | ✅ Done | --raw --tsv_stats --N50 |
| S2 — Assembly | ✅ Done | Flye (all); wtdbg2 trialed on one barcode (see CHANGELOG v1.1) |
| S3 — BUSCO | ✅ Done | hypocreales lineage; all >99.1% (see scores below) |
| S4 — EarlGrey | ✅ Done | TE repeat detection |
| S4 — Funannotate mask | ✅ Done | Soft-mask with repeatmodeler |
| S4 — BUSCO Augustus training | ✅ Done | sordariomycetes_odb10 |
| S4 — Funannotate predict | ✅ Done | ~7 hrs per isolate |
| S4 — antiSMASH | ✅ Done | Secondary metabolite cluster detection |
| S4 — Downstream annotation | 🟡 In progress | Remaining Funannotate steps pending |

#### BUSCO scores — hypocreales lineage

| Barcode | BUSCO % | Assembler |
|---------|---------|-----------|
| barcode49 | 99.2% | Flye |
| barcode50 | 99.2% | Flye |
| barcode51 | 99.3% | Flye |
| barcode52 | 99.3% | Flye |
| barcode53 | 99.2% | Flye |
| barcode55 | 99.2% | Flye |
| barcode56 | 99.2% | Flye |
| barcode57 | 99.2% | Flye |
| barcode58 | 99.1% | Flye |


#### Notes
- wtdbg2 was trialed on one barcode during assembly troubleshooting; BUSCO was run
  on that assembly but score not recorded. All final assemblies used Flye.
  Check CHANGELOG.md v1.1 for possible assembler decision rationale.
- Porechop must be loaded with miniconda unloaded — documented in README.md §11

---

### Batch 2 retrospective (batch_2025-fall) — barcodes 36–45

**Cluster:** Ceres & Atlas  
**Sequenced:** Fall 2025  
**Working directory:** `/90daydata/silage_microbiome/[path — fill in]/`  
**Scripts directory:** `/project/silage_microbiome/max.chi/fusarium_sequencing/scripts`

#### Stages completed (all barcodes unless noted)

| Stage | Status | Notes |
|-------|--------|-------|
| S1 — Concatenation | ✅ Done | |
| S1 — Deduplication | ✅ Done | |
| S1 — Porechop | ✅ Done | |
| S1 — NanoFilt | ✅ Done | |
| S1 — NanoPlot | ✅ Done | |
| S2 — Assembly | ✅ Done | Flye only (wtdbg2 not used this batch) |
| S3 — BUSCO | ✅ Done | hypocreales lineage; all >99.3% (see scores below) |
| S4 — EarlGrey | ✅ Done | |
| S4 — Funannotate mask | ✅ Done | |
| S4 — BUSCO Augustus training | ✅ Done | |
| S4 — Funannotate predict | ✅ Done | |
| S4 — antiSMASH | ✅ Done | |
| S4 — Downstream annotation | ⚪ Not started | Next priority |

#### BUSCO scores — hypocreales lineage

| Barcode | BUSCO % | Assembler |
|---------|---------|-----------|
| barcode36 | 99.4% | Flye |
| barcode37 | 99.4% | Flye |
| barcode38 | 99.3% | Flye |
| barcode39 | 99.3% | Flye |
| barcode40 | 99.4% | Flye |
| barcode41 | 99.3% | Flye |
| barcode42 | 99.3% | Flye |
| barcode43 | 99.3% | Flye |
| barcode44 | 99.3% | Flye |
| barcode45 | 99.3% | Flye |

---

## Backlog / known issues

- [ ] Locate and record wtdbg2 trial barcode and its BUSCO score — add to CHANGELOG.md
- [ ] Complete downstream Funannotate annotation steps for both batches
- [ ] Move all batch_2025-fall outputs from /90daydata/ to /project/ permanent storage
- [ ] Fill in exact Ceres working directory path for batch_2025-fall in this file and BATCHES.md

---

## Environment reference

| Item | Value |
|------|-------|
| Conda env | `seqenv` |
| Activate | `module load miniconda && source activate seqenv` |
| Porechop | `module unload miniconda && module load porechop` |
| Primary cluster | Ceres (short-mem / msn-mem) |
| Secondary cluster | Atlas |
| Project root (Ceres) | `/90daydata/silage_microbiome/` |
| Permanent storage | `/project/silage_microbiome/max.chi/` |

---

_This file is version-controlled. Do not delete old entries — they are the audit trail._
