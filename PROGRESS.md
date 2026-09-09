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
| batch_2025-Feb | 49–53, 55–58 | 🟢 S5 complete | Ceres | Move to /project/ (path TBD); funannotate compare |
| batch_2025-Dec | 36–45 | 🟢 S5 complete | Ceres | Move to /project/ (path TBD); funannotate compare |
| batch_2026-May | 01,02,04–08 | 🟢 S5 complete | Ceres/Atlas | funannotate compare |
| batch4_2026-Sep | 73–76, 81–84 | 🔵 Basecalling | MinKNOW | Complete basecalling; begin S1 concat |

> Status key: 🟢 Complete · 🔵 In progress · 🔴 Blocked · ⚪ Not started

---

## Log entries
<!-- ─── Most recent entry at TOP ─────────────────────────── -->

---

## 2026-07-28 — Ceres/Atlas — batch_2026-May — Effectorome (S5.6)

**Working directory:** `/90daydata/silage_microbiome/max_seq/batch_2026-May/`
**Barcodes in scope:** barcode01, 02, 04–08 (all 7)

### What I ran
- Script: effectorome pipeline (SignalP → Effector3.0)
- Job IDs: TBD — fill in from logs

### Outcome
- [x] Completed successfully — all 7 isolates

### Notes / observations
- Effectorome (S5.6) run separately from the main 7/23 batch due to
  compute scheduling / dependency on secretome outputs
- Sub-stages: 5.6a SignalP, 5.6b Effector3.0

### Next step
- funannotate compare across all completed isolates (26 total — prerequisite:
  confirm consistent Augustus species parameters in permanent storage)

---

## 2026-07-23 — Ceres/Atlas — batch_2026-May — Full S1→S5 run (minus effectorome)

**Working directory:** `/90daydata/silage_microbiome/max_seq/batch_2026-May/`
**Atlas working dir:** `/90daydata/silage_microbiome/Max_Batch3/`
**Barcodes in scope:** barcode01, 02, 04–08 (all 7)

### What I ran

| Stage | Script | Job IDs | Notes |
|-------|--------|---------|-------|
| S1 preprocessing | `02_porechop.sh`, `03_seqkit_dedup.sh`, `04_nanofilt.sh`, `05_nanoplot.sh` | TBD | Array 1–7 |
| Atlas HERRO correction | `A04_dorado_corr.sh` | 19845447, 19845699, 19846285, 19845700-4 | Atlas GPU; Path 1 workflow |
| S2 Flye assembly | `06_flye_assemble.sh` | TBD | `--nano-corr`; array 1–7 |
| S3 BUSCO eval | `07_busco_eval.sh` | TBD | hypocreales_odb10; offline |
| S4 EarlGrey+mask | `08_sort_earlgrey_mask.sh` | TBD | Array 1–7 |
| S4 funannotate predict | `09a_FUN_predict.sh` | TBD | Fixed script (v 2026-06-24); APPTAINERENV_AUGUSTUS_CONFIG_PATH corrected |
| S4 InterProScan | `09b_IPScan.sh` | TBD | XML output; `-dp` flag |
| S4 funannotate annotate | `09c_FUN_annotate.sh` | TBD | emapper auto-invoked |
| S5.1 Telomere | `10_telomere_search.sh` | TBD | Array 1–7; mycotools env |
| S5.2 antiSMASH | *(script TBD)* | TBD | Run on predict GBK; `--genefinding-tool none` |
| S5.3 CAZymes | *(script TBD)* | TBD | |
| S5.5 Secretome | *(script TBD)* | TBD | |

### Outcome
- [x] All 7 isolates through S1–S5 (minus S5.6 effectorome — see 2026-07-28)
- BUSCO scores: TBD — fill in from job output logs

### Notes / observations
- Path 1 (MinKNOW pre-basecalled): MinKNOW output → Ceres S1 → Atlas A04
  HERRO correction → Ceres S2 onward
- `09a_FUN_predict.sh` ran successfully for all 7 isolates using the
  2026-06-24 script fix (see session note below)
- _F. annulatum_ (barcode05): `F_verticillioides_7600_proteins.faa` used
  as protein evidence — dedicated file not confirmed; note for future batches
- Test-task-1-first pattern used before full array submission for S4 scripts

### Parameter changes from last session
| Parameter | Previous | This session | Reason |
|-----------|----------|--------------|--------|
| S1 entry point | Not started | 02_porechop onward (concat done 2026-05-27) | Resuming after May concat |
| APPTAINERENV_AUGUSTUS_CONFIG_PATH | Missing (bug) | Set correctly in 09a | Fixed 2026-06-24 |

### Next step
- Effectorome (S5.6): see 2026-07-28 entry
- Fill in all job IDs from Ceres/Atlas SLURM logs

---

## 2026-07-23 — Ceres — batch_2025-Dec — Telomere search (S5.1)

**Working directory:** `/90daydata/silage_microbiome/max_seq/jan_batch2_all_barcodes/`
**Barcodes in scope:** barcode36–45 (all 10)

### What I ran
- Script: `10_telomere_search.sh` (array job)
- Job IDs: TBD — fill in from logs

### Outcome
- [x] Completed successfully — all 10 isolates
- Outputs: TSV density files + PNG plots per contig at `13_Telomere/{sample_id}/`

### Notes / observations
- Used fixed conda activation pattern (`source conda.sh && conda activate mycotools`)
  — the batch-node Bio import failure that affected batch_2025-Feb interactive
  run was resolved in `10_telomere_search.sh`

### Next step
- Remaining S5 sub-stages (antiSMASH, CAZymes, BigScape, effectorome): fill in
  dates/job IDs from Atlas logs

---

## 2026-07-22 — Ceres — batch_2025-Feb — antiSMASH (S5.2)

**Working directory:** `/90daydata/silage_microbiome/max_seq/batch1_all_barcodes/`
**Barcodes in scope:** barcode49–53, 55–58 (all 9)

### What I ran
- Script: antiSMASH array job
- Job IDs: TBD — fill in from logs

### Outcome
- [x] Completed successfully — all 9 isolates

### Notes / observations
- Run on funannotate predict GBK (not raw assembly) — gene IDs match for
  funannotate annotate merge
- `--genefinding-tool none` flag used to suppress empty-scaffold errors

### Next step
- CAZymes, BigScape, effectorome for batch_2025-Feb: fill in from Atlas logs
- Telomere for batch_2025-Dec: see 2026-07-23 entry

---

## 2026-06-24 — Ceres — Script fix — 09a_FUN_predict.sh (APPTAINERENV_AUGUSTUS_CONFIG_PATH)

**Barcodes in scope:** N/A — script update only

### What I ran
- Updated `09a_FUN_predict.sh`: added `APPTAINERENV_AUGUSTUS_CONFIG_PATH`
  (previously `AUGUSTUS_CONFIG_PATH` was set but not propagated into
  the Apptainer container)

### Outcome
- [x] Script updated; not yet run on batch_2026-May at this point
- Tested and confirmed working during batch_2026-May full run (2026-07-23)

### Notes / observations
- Root cause: Apptainer requires the `APPTAINERENV_` prefix to propagate
  any env var into the container. Without it, Augustus fell back to the
  container's ephemeral config layer, discarding trained species parameters.
- Fix: `export APPTAINERENV_AUGUSTUS_CONFIG_PATH="${DB_ROOT}/augustus_config/config"`
- This is a prerequisite for `funannotate compare` — all isolates must have
  Augustus parameters written to the same persistent `AUGUSTUS_CONFIG_PATH`

### Next step
- Run updated `09a_FUN_predict.sh` for batch_2026-May on 2026-07-23

---

## 2026-05-27 — Ceres — batch_2025-Feb — Telomere density search (interactive)

**Working directory:** `/90daydata/silage_microbiome/max_seq/batch1_all_barcodes/`
**Barcodes in scope:** barcode49–53, 55–58 (all 9)

### What I ran
- Script: `scripts/telomere_density.py` (custom Python script)
- Execution: **Interactive node** — not submitted as sbatch
- Command per isolate:
```bash
srun -A silage_microbiome -N 1 -n 4 -p ceres -t 2:00:00 --pty bash
module load miniconda
source activate seqenv
python scripts/telomere_density.py \
    -i ${POLISHED_DIR}/${assembly_file} \
    -o ${TELOMERE_DIR}/${sample_id}_telomere_density.tsv \
    --outdir ${TELOMERE_DIR}/${sample_id}/plots \
    --window 10000 --step 1000
```
- Also ran: `01_concat.sh` array for batch_2026-May (7 isolates, barcode01/02/04–08)

### Outcome
- [x] Telomere: Completed successfully — all 9 batch_2025-Feb isolates
- [x] batch_2026-May concat: Completed successfully — all 7 isolates
- Outputs: TSV density files + PNG plots per contig per isolate

### Notes / observations
- ⚠️ Telomere could not run as SLURM batch/array job — `from Bio import SeqIO`
  failed on batch nodes due to conda environment not being activated
  in the non-interactive shell
- Root cause: `module load miniconda` alone is insufficient for batch
  nodes — conda env must be explicitly activated via
  `source $(conda info --base)/etc/profile.d/conda.sh && conda activate mycotools`
- **Fixed in `10_telomere_search.sh`** — new array wrapper handles
  conda activation correctly; ready to use for batch_2025-Dec (run 2026-07-23)
- Plots and TSVs written to `13_Telomere/{sample_id}/`
- batch_2026-May concat: `01_concat.sh` manifest-driven; reads
  `config/manifests/batch_2026-May_manifest.tsv`; skip-if-exists logic active

### Parameter changes from last session
| Parameter | Previous | This session | Reason |
|-----------|----------|--------------|--------|
| Telomere search | Not run | Added as S5.1 stage | New analysis |
| Window size | — | 10,000 bp | Default; captures telomeric regions |
| Step size | — | 1,000 bp | 1 kb resolution |

### Next step
- Resolved: batch_2025-Dec telomere run 2026-07-23
- Resolved: batch_2026-May full pipeline run 2026-07-23

---

## 2026-04-29 — Ceres — batch_2025-Feb — Full S4 rerun (sort → EarlGrey → mask → predict → annotate)

**Working directory:** `/90daydata/silage_microbiome/max_seq/batch1_all_barcodes/`
**Barcodes in scope:** barcode49–53, 55–58 (all 9)

### Context
Full reanalysis of batch_2025-Feb using pre-existing Flye assemblies. BUSCO
evaluation ran in parallel on existing assemblies. All array jobs used task 1
as a test before submitting tasks 2–9. First use of manifest-driven
architecture and refactored scripts (07–09c). DB paths migrated to /project/.

### What I ran

| Stage | Script | Job IDs | Notes |
|-------|--------|---------|-------|
| BUSCO eval | `07_busco_eval.sh` | 20579367_1–9 | Parallel to sort/mask; pre-existing assemblies |
| Sort+EarlGrey+Mask | `08_sort_earlgrey_mask.sh` | 20589974_1–9 | New combined script |
| Funannotate predict | `09a_FUN_predict.sh` | 20613158_1, 20613258_2–9 | Task 1 test then 2–9 |
| InterProScan | `09b_IPScan.sh` | 20618475_1, 20619448_2–9 | Task 1 test then 2–9 |
| Funannotate annotate | `09c_FUN_annotate.sh` | 20619524_1, 20620393_2–9 | Task 1 test then 2–9 |

### Outcome
- [x] All 9 isolates through all stages successfully

### Notes / observations
- DB paths migrated to permanent storage (see CHANGELOG v1.4)
- Annotate outputs co-located in predict directory (expected — see CHANGELOG v1.4)
- `11c_FUN_Annotate_Result/` removed from paths.sh

### Next step
- Resolved: telomere search run 2026-05-27

---

## 2026-04-21 — Ceres — batch_2025-Dec — IPRScan + funannotate annotate

**Working directory:** `/90daydata/silage_microbiome/max_seq/jan_batch2_all_barcodes/`
**Barcodes in scope:** barcode36–45 (all 10)

| Stage | Script | Job IDs | Outcome |
|-------|--------|---------|---------|
| IPRScan | `09b_IPScan.sh` | 20526945_1–10 | ✅ All complete |
| Funannotate annotate | `09c_FUN_annotate.sh` | 20535822_1–10 | ✅ All complete |

---

## 2026-04-20 — Ceres — batch_2025-Dec — Troubleshooting

- IPRScan manual test on barcode36 — ✅
- funannotate annotate on barcode37 — ❌ (APPTAINERENV_FUNANNOTATE_DB unresolved)
- Resolved 2026-04-21

---

## 2025-02-14 — Pipeline formalized — Both batches retrospective

### batch_2025-Feb (barcode49–53, 55–58) — BUSCO scores

| Barcode | Isolate | Species | BUSCO % |
|---------|---------|---------|---------|
| barcode49 | F-Arl-23.2 | _F. proliferatum_ | 99.2% |
| barcode50 | F-22-6 | _F. fujikuroi_ | 99.2% |
| barcode51 | F-22-24 | _F. fujikuroi_ | 99.3% |
| barcode52 | F-22-6 | _F. fujikuroi_ | 99.3% ✅ verified |
| barcode53 | F-23-5.2 | _F. proliferatum_ | 99.2% |
| barcode55 | F-23-2.3 | Put. _F. subglutinans_ | 99.2% |
| barcode56 | F-23-4.4 | _F. cerealis_ | 99.2% |
| barcode57 | Fg-23-1.3 | _F. graminearum_ | 99.2% |
| barcode58 | F-Arl-23.2b | _F. proliferatum_ | 99.1% |

### batch_2025-Dec (barcode36–45) — BUSCO scores

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

- [ ] Fill in all job IDs for batch_2026-May (S1–S5) from Ceres/Atlas logs
- [ ] Fill in batch_2025-Dec S5 sub-stage dates/job IDs from Atlas logs
- [ ] Fill in batch_2025-Feb S5 CAZymes, BigScape, effectorome dates/job IDs
- [ ] Fill in batch_2026-May BUSCO scores from 07_busco_eval.sh output
- [ ] Locate wtdbg2 trial barcode and BUSCO score — add to CHANGELOG v1.1
- [ ] Move batch_2026-May outputs to `/project/` permanent storage
- [ ] Confirm permanent storage full paths for batch_2025-Feb and batch_2025-Dec
- [ ] Update BATCHES.md permanent storage index for all three batches once paths confirmed
- [ ] Confirm which S5 stages ran on Atlas vs Ceres for batch_2025-Dec
- [ ] Run funannotate compare across all 26 completed isolates
      (prerequisite: confirm APPTAINERENV_AUGUSTUS_CONFIG_PATH fix active for
      batch_2025-Feb and batch_2025-Dec — re-check before compare)
- [ ] Confirm _F. annulatum_ protein evidence situation (barcode05 / barcode74):
      F_verticillioides_7600 used in batch 3; confirm whether dedicated file
      exists or should be sourced from NCBI

---

## Environment reference

| Item | Value |
|------|-------|
| Conda env (general) | `seqenv` |
| Conda env (telomere) | `mycotools` |
| Activate (interactive) | `module load miniconda && source activate <env>` |
| Activate (batch scripts) | `source $(conda info --base)/etc/profile.d/conda.sh && conda activate <env>` |
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
