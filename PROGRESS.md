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
| batch_2025-Feb | 49–53, 55–58 | 🟡 S5 in progress (telomere done) | Ceres | Run telomere on batch 2; CAZymes; antiSMASH |
| batch_2025-Dec | 36–45 | 🟢 S4 complete | Ceres | Run telomere search (array); begin S5 |
| batch_2026-May | 01,02,04–08 | ⚪ S1 starting | Ceres | Concatenation |

> Status key: 🟢 Complete · 🟡 In progress · 🔴 Blocked · ⚪ Not started

---

## Log entries
<!-- ─── Most recent entry at TOP ─────────────────────────── -->

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

### Outcome
- [x] Completed successfully — all 9 isolates processed
- Outputs: TSV density files + PNG plots per contig per isolate

### Notes / observations
- ⚠️ Could not run as SLURM batch/array job — `from Bio import SeqIO`
  failed on batch nodes due to conda environment not being activated
  in the non-interactive shell
- Ran manually on an interactive node as a workaround
- Root cause: `module load miniconda` alone is insufficient for batch
  nodes — conda env must be explicitly activated via
  `source $(conda info --base)/etc/profile.d/conda.sh && conda activate seqenv`
- **Fixed in `10_telomere_search.sh`** — new array wrapper handles
  conda activation correctly; ready to use for batch_2025-Dec
- Plots and TSVs written to `13_Telomere/{sample_id}/`

### Parameter changes from last session
| Parameter | Previous | This session | Reason |
|-----------|----------|--------------|--------|
| Telomere search | Not run | Added as S5 stage | New analysis |
| Window size | — | 10,000 bp | Default; captures telomeric regions |
| Step size | — | 1,000 bp | 1 kb resolution |

### Next step
- Run `10_telomere_search.sh` array for batch_2025-Dec (barcode36–45)
- Begin batch_2026-May: concatenation with `01_concat.sh`
- Prep: confirm `batch3_manifest.tsv` is in place on Ceres at
  `/90daydata/silage_microbiome/max_seq/batch_2026-May/`
- Note: `barlist.txt` no longer needed for new batches — manifest is the
  single source of truth (see CHANGELOG v1.5)

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
| barcode52 | F-22-6 | _F. fujikuroi_ | 99.3% ⚠️ verify |
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

- [ ] Verify barcode52 BUSCO score — currently inferred as 99.3%
- [ ] Locate wtdbg2 trial barcode and BUSCO score — add to CHANGELOG v1.1
- [ ] Run `10_telomere_search.sh` array on batch_2025-Dec (fixed script ready)
- [ ] Move batch_2025-Feb outputs to `/project/` permanent storage
- [ ] Move batch_2025-Dec outputs to `/project/` permanent storage
- [ ] Update BATCHES.md permanent storage index for both batches once moved
- [ ] Confirm which stages ran on Atlas vs Ceres for batch_2025-Dec
- [ ] Begin S5 CAZymes + antiSMASH for both batches
- [ ] Add protein evidence file for _F. annulatum_ to PROTEIN_EVIDENCE_DIR
      (not seen in previous batches — verify file exists before batch 3 predict)
- [ ] Confirm whether `funannotate setup -u -w -d $DB` needed before annotate

---

## Environment reference

| Item | Value |
|------|-------|
| Conda env | `seqenv` |
| Activate (interactive) | `module load miniconda && source activate seqenv` |
| Activate (batch scripts) | `source $(conda info --base)/etc/profile.d/conda.sh && conda activate seqenv` |
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
