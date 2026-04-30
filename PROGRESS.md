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
## YYYY-MM-DD — [Ceres | Atlas] — Batch: [batch_name]

**Working directory:** /90daydata/silage_microbiome/[path]/
**Barcodes in scope:** barcode##, ##, ##

### What I ran
- Script / command:
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
| batch_2025-Feb | 49–53, 55–58 | 🟢 S4 complete | Ceres | Move to /project/; begin S5 |
| batch_2025-Dec | 36–45 | 🟢 S4 complete | Ceres | Move to /project/; begin S5 |

> Status key: 🟢 Complete · 🟡 In progress · 🔴 Blocked · ⚪ Not started

---

## Log entries
<!-- ─── Most recent entry at TOP ─────────────────────────── -->

---

## 2026-04-29 — Ceres — batch_2025-Feb — Full S4 rerun (sort → EarlGrey → mask → predict → annotate)

**Working directory:** `/90daydata/silage_microbiome/max_seq/batch1_all_barcodes/`
**Barcodes in scope:** barcode49–53, 55–58 (all 9)

### Context
Full reanalysis of batch_2025-Feb starting from sort → EarlGrey → mask, using
pre-existing Flye assemblies in `07_Polished_Genome/`. BUSCO evaluation was
submitted separately and ran in parallel on those same pre-existing assemblies —
this was intentional, not an error. All array jobs used task 1 as a test run
before submitting tasks 2–9 as a separate submission. This session also introduced
the manifest-driven array architecture (`batch1_manifest.tsv`) and the
refactored/renamed scripts (07–09c). DB paths moved from /90daydata/ to
permanent /project/ storage.

### What I ran

**BUSCO evaluation — pre-existing assemblies (parallel):**
- Script: `scripts/07_busco_eval.sh` *(new script)*
- Job IDs: 20579367_1–9
- Note: Submitted independently; ran in parallel with sort/mask pipeline

**Sort + EarlGrey + Mask:**
- Script: `scripts/08_sort_earlgrey_mask.sh` *(new script — combines 3 steps)*
- Job IDs: 20589974_1–9
- Steps: `funannotate sort` → EarlGrey (Apptainer) → `funannotate mask`

**Funannotate predict:**
- Script: `scripts/09a_FUN_predict.sh` *(renamed)*
- Job IDs: 20613158_1 (test), 20613258_2–9 (full array)

**InterProScan:**
- Script: `scripts/09b_IPScan.sh` *(renamed from IPscan.sh)*
- Job IDs: 20618475_1 (test), 20619448_2–9 (full array)

**Funannotate annotate:**
- Script: `scripts/09c_FUN_annotate.sh` *(renamed from 10_FUN_annotate.sh)*
- Job IDs: 20619524_1 (test), 20620393_2–9 (full array)

### Outcome
- [x] Completed successfully — all 9 isolates through all stages

### Notes / observations
- All stages used task 1 as test before submitting tasks 2–9 separately —
  confirmed as the standard testing pattern going forward
- BUSCO ran on pre-existing assemblies in parallel with sort/EarlGrey/mask —
  deliberate; assemblies already existed from original batch 1 run
- New manifest-driven architecture: `batch1_manifest.tsv` at
  `${BATCH_DIR}/batch1_manifest.tsv` drives all stages 07–09c
  (replaces barlist.txt for annotation stages)
- DB paths all moved to permanent storage — see parameter changes below
- Annotate outputs landed inside predict directory per isolate
  (confirmed expected funannotate behavior — decision to accept this
  documented in CHANGELOG.md v1.4):
  `11a_FUN_Predict_Result/FunAnnotate_{sampleID}/annotate_misc/`
  `11a_FUN_Predict_Result/FunAnnotate_{sampleID}/annotate_results/`
- `11c_FUN_Annotate_Result/` removed from paths.sh (see CHANGELOG v1.4)
- busco_eval now uses `--offline` flag with local lineage at
  `${BUSCO_DOWNLOADS}/lineages/hypocreales_odb10`

### Parameter changes from last session
| Parameter | Previous | This session | Reason |
|-----------|----------|--------------|--------|
| BATCH_ID | `jan_batch2_all_barcodes` | `batch1_all_barcodes` | Switching to batch 1 |
| DB location | `/90daydata/` (temporary) | `/project/silage_microbiome/max.chi/fusarium_sequencing/DB_Databases/` | Moved to permanent storage |
| Sample manifest | barlist.txt | `batch1_manifest.tsv` | New manifest-driven architecture for stages 07–09c |
| BUSCO CPUs | 70 | 8 | Right-sized for evaluation |
| BUSCO memory | 900 GB | 40 GB | Right-sized |
| Sort+EarlGrey+Mask | Separate scripts | Combined `08_sort_earlgrey_mask.sh` | Streamlined |
| IPRScan CPUs | Passed via terminal | `${SLURM_NTASKS}` from #SBATCH header | Fixed in renamed script |
| `11c_FUN_Annotate_Result/` | In paths.sh mkdir block | Removed | Accepted funannotate's co-location behavior |

### Next step
- Verify annotate_results present for all 9 isolates in `11a_FUN_Predict_Result/`
- Move batch_2025-Feb outputs to `/project/` permanent storage
- Update BATCHES.md permanent storage index for barcode49–53, 55–58
- Begin S5 genome-wide analyses (telomere search, CAZymes) for both batches

---

## 2026-04-21 — Ceres — batch_2025-Dec — Funannotate annotate

**Working directory:** `/90daydata/silage_microbiome/max_seq/jan_batch2_all_barcodes/`
**Barcodes in scope:** barcode36–45 (all 10)

### What I ran
- Script: `scripts/10_FUN_annotate.sh` *(now renamed 09c_FUN_annotate.sh)*
- Job IDs: 20535822_1 (test), 20535822_2–10

### Outcome
- [x] Completed successfully — all 10 array tasks finished

### Notes / observations
- Resolving `APPTAINERENV_FUNANNOTATE_DB` path was key fix from 04-20 failure
- Ran without eggnog (intentional)
- Annotate outputs in predict directory (see CHANGELOG v1.3, v1.4)
- This completes S4 for all batch_2025-Dec isolates

### Next step
- Move outputs to /project/; begin S5 analyses

---

## 2026-04-21 — Ceres — batch_2025-Dec — IPRScan array

**Working directory:** `/90daydata/silage_microbiome/max_seq/jan_batch2_all_barcodes/`
**Barcodes in scope:** barcode36–45 (all 10)

### What I ran
- Script: `scripts/09b_IPScan.sh` *(renamed from IPscan.sh)*
- Job IDs: 20526945_1–10

### Outcome
- [x] All 10 completed successfully

### Notes / observations
- SLURM #SBATCH header flags ignored on this run — flags passed via terminal
  Fixed in renamed `09b_IPScan.sh` using `${SLURM_NTASKS}`
- PROJECT_ROOT BASH_SOURCE bug fixed (see CHANGELOG v1.3)
- Output XMLs written to `11b_InterProScan/`

### Next step
- Confirmed all 10 XMLs non-empty → submitted funannotate annotate

---

## 2026-04-20 — Ceres — batch_2025-Dec — Troubleshooting session

**Working directory:** `/90daydata/silage_microbiome/max_seq/jan_batch2_all_barcodes/`
**Barcodes in scope:** barcode36, barcode37 (test)

### What I ran
- IPRScan manual test on barcode36 — ✅ completed (80 CPUs; informed array design)
- funannotate annotate on barcode37 — ❌ failed (APPTAINERENV_FUNANNOTATE_DB unresolved)

### Next step
- Resolved 2026-04-21: DB path confirmed, array jobs completed

---

## 2025-02-14 — Pipeline formalized — Both batches context

**Note:** Reconstructed entry covering work completed prior to formal tracking.

### Batch 1 retrospective (batch_2025-Feb) — barcodes 49–53, 55–58

**Cluster:** Ceres
**Working directory:** `/90daydata/silage_microbiome/max_seq/Max_pod_5s/isolate_fastq/`

| Stage | Status |
|-------|--------|
| S1 — Preprocessing | ✅ Done |
| S2 — Assembly (Flye) | ✅ Done |
| S3 — BUSCO (hypocreales) | ✅ Done |
| S4 — EarlGrey / Mask / Predict / antiSMASH | ✅ Done (original run) |
| S4 — IPRScan + Funannotate annotate | ✅ Done (2026-04-29 rerun) |

#### BUSCO scores — hypocreales lineage

| Barcode | Isolate | Species | BUSCO % |
|---------|---------|---------|---------|
| barcode49 | F-Arl-23.2 | _F. proliferatum_ | 99.2% |
| barcode50 | F-22-6 | _F. fujikuroi_ | 99.2% |
| barcode51 | F-22-24 | _F. fujikuroi_ | 99.3% |
| barcode52 | F-22-6 | _F. fujikuroi_ | 99.3% ⚠️ *verify* |
| barcode53 | F-23-5.2 | _F. proliferatum_ | 99.2% |
| barcode55 | F-23-2.3 | Put. _F. subglutinans_ | 99.2% |
| barcode56 | F-23-4.4 | _F. cerealis_ | 99.2% |
| barcode57 | Fg-23-1.3 | _F. graminearum_ | 99.2% |
| barcode58 | F-Arl-23.2b | _F. proliferatum_ | 99.1% |

### Batch 2 retrospective (batch_2025-Dec) — barcodes 36–45

**Cluster:** Ceres & Atlas
**Working directory:** `/90daydata/silage_microbiome/max_seq/jan_batch2_all_barcodes/`

| Stage | Status |
|-------|--------|
| S1–S3 | ✅ Done |
| S4 — EarlGrey / Mask / Predict / antiSMASH | ✅ Done |
| S4 — IPRScan | ✅ Done (job 20526945_1–10, 2026-04-21) |
| S4 — Funannotate annotate | ✅ Done (job 20535822_1–10, 2026-04-21) |

#### BUSCO scores — hypocreales lineage

| Barcode | Isolate | Species | BUSCO % |
|---------|---------|---------|---------|
| barcode36 | F-22-12a | _F. sporotrichioides_ | 99.4% |
| barcode37 | F-22-12b | _F. sporotrichioides_ | 99.4% |
| barcode38 | Fg-22-214.4 | _F. graminearum_ | 99.3% |
| barcode39 | Fg-23-10 | _F. graminearum_ | 99.3% |
| barcode40 | F-Arl-23.6 | _F. proliferatum_ | 99.4% |
| barcode41 | Fg-23-7.2 | _F. graminearum_ | 99.3% |
| barcode42 | F-23-8.10 | _F. proliferatum_ | 99.3% |
| barcode43 | Fg-23-8.6 | _F. graminearum_ | 99.3% |
| barcode44 | F-25-8710-1 | Put. _F. ipomoea_ | 99.3% |
| barcode45 | F-23-8710-3 | _F. proliferatum_ | 99.3% |

---

## Backlog / known issues

- [ ] Verify barcode52 BUSCO score — currently inferred as 99.3%
- [ ] Locate wtdbg2 trial barcode and BUSCO score — add to CHANGELOG.md v1.1
- [ ] Move batch_2025-Feb outputs to `/project/` permanent storage
- [ ] Move batch_2025-Dec outputs to `/project/` permanent storage
- [ ] Update BATCHES.md permanent storage index for both batches once moved
- [ ] Confirm which stages ran on Atlas vs Ceres for batch_2025-Dec
- [ ] Begin S5 analyses (telomere search, antiSMASH, CAZymes) for both batches
- [ ] Confirm whether `funannotate setup -u -w -d $DB` is needed before annotate

---

## Environment reference

| Item | Value |
|------|-------|
| Conda env | `seqenv` |
| Activate | `module load miniconda && source activate seqenv` |
| Porechop | `module unload miniconda && module load porechop` |
| Primary cluster | Ceres |
| Secondary cluster | Atlas |
| Project root | `/project/silage_microbiome/max.chi/fusarium_sequencing` |
| DB root | `/project/silage_microbiome/max.chi/fusarium_sequencing/DB_Databases` |
| FUNANNOTATE_DB | `${DB_ROOT}/funannotate_db` |
| AUGUSTUS_CONFIG_PATH | `${DB_ROOT}/augustus_config/config` |
| EARLGREY_SIF | `${PROJECT_ROOT}/Containers/earlgrey_dfam3.7_latest.sif` |
| Scratch root | `/90daydata/silage_microbiome/max_seq/` |

---

_This file is version-controlled. Do not delete old entries — they are the audit trail._
