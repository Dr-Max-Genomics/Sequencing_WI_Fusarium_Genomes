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
| batch_2025-02 (Batch 1) | 49–53, 55–58 | 🟡 Downstream annotation in progress | Ceres | Complete IPRScan + funannotate annotate |
| batch_2025-fall (Batch 2) | 36–45 | 🟢 S4 annotation complete | Ceres | Move outputs to /project/ permanent storage |

> Status key: 🟢 Complete · 🟡 In progress · 🔴 Blocked · ⚪ Not started

---

## Log entries
<!-- ─── Most recent entry at TOP ─────────────────────────── -->

---

## 2026-04-21 — Ceres — Batch: batch_2025-fall — Funannotate annotate

**Working directory:** `/90daydata/silage_microbiome/max_seq/jan_batch2_all_barcodes/`
**Barcodes in scope:** barcode36–45 (all 10)

### What I ran
- Script: `scripts/10_FUN_annotate.sh`
- Submitted as SLURM array job: `sbatch --array=1-10 scripts/10_FUN_annotate.sh`
- Job IDs: 20535822_1 through 20535822_10

### Outcome
- [x] Completed successfully — all 10 array tasks finished

### Notes / observations
- Resolving `APPTAINERENV_FUNANNOTATE_DB` path was the key fix from the
  failed 04-20 run. Correct path confirmed as:
  `/90daydata/silage_microbiome/max_seq/jan_batch2_all_barcodes/11_FunAnnotate/DB_FunannotateDatabase/funannotate_db`
- Ran without eggnog (see 04-20 notes)
- ⚠️ **Unexpected output location:** Script `10_FUN_annotate.sh` specifies
  `11c_FUN_Annotate_Result/` as the output directory, but funannotate annotate
  detected existing `predict_misc/` and `predict_results/` directories inside
  `11a_FUN_Predict_Result/FunAnnotate_{sampleID}/` and wrote `annotate_misc/`
  and `annotate_results/` into those same per-sample subdirectories instead of
  the intended output path.
- **Actual output location** (all 10 isolates):
  `11a_FUN_Predict_Result/FunAnnotate_{sampleID}/annotate_misc/`
  `11a_FUN_Predict_Result/FunAnnotate_{sampleID}/annotate_results/`
- This behavior is consistent with funannotate's design — it expects predict
  and annotate to share the same project directory and uses the existing
  structure as an anchor. The `-i` input flag in the script pointed to the
  predict directory, so funannotate treated it as the project root.
- ⚠️ **Action needed before batch 1 run:** Review `10_FUN_annotate.sh` — either
  update the script to explicitly pass the predict directory as `-i` (accepting
  that annotate outputs will land there), or restructure so outputs go to
  `11c_FUN_Annotate_Result/` as intended. Document the decision in CHANGELOG.md.
- This completes S4 for all batch_2025-fall isolates

### Parameter changes from last session
| Parameter | Previous | This session | Reason |
|-----------|----------|--------------|--------|
| APPTAINERENV_FUNANNOTATE_DB | Unresolved (two candidate paths) | Path A confirmed (see notes) | Required for funannotate annotate to find DB |

### Next step
- Investigate `10_FUN_annotate.sh` output path behavior before running on batch 1
- Move batch_2025-fall outputs to `/project/` permanent storage
- Prep needed: Verify all 10 annotate output dirs are non-empty in `11a_FUN_Predict_Result/`
- After move: Update BATCHES.md permanent storage index for barcode36–45

---

## 2026-04-21 — Ceres — Batch: batch_2025-fall — IPRScan array

**Working directory:** `/90daydata/silage_microbiome/max_seq/jan_batch2_all_barcodes/`
**Barcodes in scope:** barcode36–45 (all 10)

### What I ran
- Script: `scripts/09_IPscan_annotate.sh`
- Submitted as SLURM array job: `sbatch --array=1-10 scripts/09_IPscan_annotate.sh`
- Job IDs: 20526945_1 through 20526945_10

### Outcome
- [x] Completed successfully — all 10 array tasks finished

### Notes / observations
- SLURM refused to read `#SBATCH` flags embedded in the script header;
  flags were passed directly from the terminal after `ml interproscan`
- Fixed `BASH_SOURCE[0]` / PROJECT_ROOT spool path bug before submission
  (hardcoded PROJECT_ROOT in `config/paths.sh` — see CHANGELOG.md v1.3)
- Output XML files written to: `11b_InterProScan/`

### Parameter changes from last session
| Parameter | Previous | This session | Reason |
|-----------|----------|--------------|--------|
| PROJECT_ROOT resolution | Dynamic via BASH_SOURCE[0] | Hardcoded in paths.sh | SLURM spool path broke dynamic resolution |

### Next step
- Script / stage: `funannotate annotate` (S4 downstream annotation) for batch_2025-fall
- Prep needed: Confirm all 10 XML files non-empty ✅ — confirmed before submitting annotate

---

## 2026-04-20 — Ceres — Batch: batch_2025-fall — Troubleshooting session

**Working directory:** `/90daydata/silage_microbiome/max_seq/jan_batch2_all_barcodes/`
**Barcodes in scope:** barcode36, barcode37 (test barcodes)

### What I ran

**Test 1 — IPRScan manual run on barcode36:**
```bash
ml purge
ml interproscan
sbatch -A silage_microbiome -N 1 -n 80 -p ceres -t 1-00 \
  --wrap="interproscan.sh -i bar36_predict_results/FusBar36_new.proteins.fa \
  -f tsv,xml -dp --cpu 80 -goterms -iprlookup -pa"
```

**Test 2 — funannotate annotate on barcode37 (failed):**
```bash
export AUGUSTUS_CONFIG_PATH=/90daydata/silage_microbiome/max_seq/jan_batch2_all_barcodes/11_FunAnnotate/augustus/config
sbatch -A silage_microbiome -N 1 -n 32 --mem=150GB -p ceres -t 6:00:00 \
  --wrap="funannotate annotate -i Bar37_predict_results/ \
  --iprscan FusBar37_IP.proteins.fa.xml \
  --antismash FusBar37.scaffolds_antiSMASH.gbk \
  --out bar37_annotate_results --cpus 32"
```

### Outcome
- [x] IPRScan manual test — completed (informed array job design for 04-21)
- [x] funannotate annotate bar37 — **failed**

### Notes / observations
- `APPTAINERENV_FUNANNOTATE_DB` path unresolved at time of this run — two
  candidate paths identified (see CHANGELOG.md v1.3); this was likely the
  cause of the funannotate annotate failure
- Ran without eggnog intentionally
- `funannotate setup -u -w -d $DB` command noted but not confirmed as
  necessary — revisit before batch 1 annotation run
- IPRScan manual test used 80 CPUs vs 32 in the array job — 32 confirmed
  as optimal (see CHANGELOG.md v1.3)

### Parameter changes from last session
| Parameter | Previous | This session | Reason |
|-----------|----------|--------------|--------|
| — | — | — | Troubleshooting session — no confirmed parameter changes |

### Next step
- Resolved by 04-21 session: IPRScan array submitted and completed;
  funannotate annotate rerun successfully after resolving DB path

---

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
| S4 — IPRScan | ⚪ Not started | Pending — needed before funannotate annotate |
| S4 — Funannotate annotate | ⚪ Not started | Pending IPRScan completion |

#### BUSCO scores — hypocreales lineage

| Barcode | BUSCO % | Assembler |
|---------|---------|-----------|
| barcode49 | 99.2% | Flye |
| barcode50 | 99.2% | Flye |
| barcode51 | 99.3% | Flye |
| barcode52 | 99.3% | Flye ⚠️ *verify — inferred from data* |
| barcode53 | 99.2% | Flye |
| barcode55 | 99.2% | Flye |
| barcode56 | 99.2% | Flye |
| barcode57 | 99.2% | Flye |
| barcode58 | 99.1% | Flye |

#### Notes
- wtdbg2 trialed on one barcode during troubleshooting; BUSCO run on that
  assembly but score not recorded. All final assemblies used Flye.
  See CHANGELOG.md v1.1 for assembler decision rationale.
- Porechop must be loaded with miniconda unloaded — documented in README.md §11

---

### Batch 2 retrospective (batch_2025-fall) — barcodes 36–45

**Cluster:** Ceres & Atlas
**Sequenced:** Fall 2025
**Working directory:** `/90daydata/silage_microbiome/max_seq/jan_batch2_all_barcodes/`
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
| S4 — IPRScan | ✅ Done | Job 20526945_1–10 (2026-04-21) |
| S4 — Funannotate annotate | ✅ Done | Job 20535822_1–10 (2026-04-21) |

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

- [ ] Verify barcode52 BUSCO score — currently inferred as 99.3%
- [ ] Locate wtdbg2 trial barcode and BUSCO score — add to CHANGELOG.md v1.1
- [ ] Run IPRScan + funannotate annotate for batch_2025-02 (barcode49–53, 55–58)
- [ ] Confirm whether `funannotate setup -u -w -d $DB` is required before annotate runs
- [ ] ⚠️ Investigate `10_FUN_annotate.sh` output path behavior — annotate outputs landed in
      `11a_FUN_Predict_Result/FunAnnotate_{sampleID}/` instead of `11c_FUN_Annotate_Result/`
      Decide: accept this as funannotate's expected behavior, or fix the script before batch 1
- [ ] Move batch_2025-fall outputs from /90daydata/ to /project/ permanent storage
      (outputs are in `11a_FUN_Predict_Result/FunAnnotate_{sampleID}/annotate_*/`)
- [ ] Update BATCHES.md permanent storage index once batch_2025-fall outputs are moved
- [ ] Fill in which stages ran on Atlas vs Ceres for batch_2025-fall

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
| FUNANNOTATE_DB (confirmed) | `/90daydata/silage_microbiome/max_seq/jan_batch2_all_barcodes/11_FunAnnotate/DB_FunannotateDatabase/funannotate_db` |
| AUGUSTUS_CONFIG_PATH | `/90daydata/silage_microbiome/max_seq/jan_batch2_all_barcodes/11_FunAnnotate/augustus/config` |

---

_This file is version-controlled. Do not delete old entries — they are the audit trail._
