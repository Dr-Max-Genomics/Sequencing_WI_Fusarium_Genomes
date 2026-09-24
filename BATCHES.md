# Isolate batch tracker

This file tracks the processing status of every *Fusarium* isolate across all batches.
It is the single source of truth for "what has been done to which isolate."

> Update whenever an isolate advances. Commit alongside `PROGRESS.md`.
> For session notes, see [`PROGRESS.md`](PROGRESS.md).

---

## Status key

| Symbol | Meaning |
|--------|---------|
| ⚪ | Not started |
| 🔵 | In progress |
| 🟢 | Complete |
| 🔴 | Blocked / failed |
| ⏸️ | On hold |

## Stage codes

| Code | Stage |
|------|-------|
| `S1` | Preprocessing (concat → porechop → dedup → nanofilt → nanoplot) |
| `S2` | Genome assembly (Flye) |
| `S3` | Assembly evaluation (BUSCO — hypocreales) |
| `S4` | Genome annotation (sort → EarlGrey → mask → predict → IPRScan → annotate) |
| `S5` | Genome-wide analyses (5.1 telomere · 5.2 antiSMASH · 5.3 CAZymes · 5.4 BigScape · 5.5 secretome · 5.6 effectorome) |
| `DONE` | All stages complete, in permanent storage |

> **Run-order note (added 2026-09):** `11_antismash.sh` (tracked under S5.2
> below, "antiSMASH") must actually run and finish **before** the S4
> `09c_FUN_annotate.sh` step, since `funannotate annotate --antismash`
> consumes its GBK output. The S4/S5 category split in this file is kept for
> consistency with existing tracking, but the file numbers do not reflect
> execution order. See `README.md` §5 "Pipeline at a glance" for the full
> explicit script sequence.

---

## Summary

| Batch | Isolates | S1 | S2 | S3 | S4 | S5 | Notes |
|-------|----------|----|----|----|----|----|-------|
| batch_2025-Feb | 9 | 9 | 9 | 9 | 9 | 🟢 | All stages complete; outputs in /project/ |
| batch_2025-Dec | 10 | 10 | 10 | 10 | 10 | 🟢 | All stages complete; outputs in /project/ |
| batch_2026-May | 7 | 7 | 7 | 7 | 7 | 🟢 | All stages complete |
| batch4_2026-Sep | 8 | 8 | 8 | 8 | 🔵 | 🔵 | Path 2 (self-basecalled on Atlas, not MinKNOW); S4 in progress — see isolate table |
| **Total** | **34** | **34** | **34** | **34** | **26 done + 8 in progress** | — | |

> Status key: 🟢 Complete · 🔵 In progress · 🔴 Blocked · ⚪ Not started

---

## Detailed isolate status

### batch_2025-Feb

**Sequencing date:** 2025-02-03
**Barlist:** [`batches/batch_2025-Feb/barlist.txt`](batches/batch_2025-Feb/barlist.txt)
**Manifest:** `config/manifests/batch_2025-Feb_manifest.tsv`
**Ceres working path:** `/90daydata/silage_microbiome/max_seq/batch1_all_barcodes/`
**Permanent storage:** `/project/silage_microbiome/` *(fill in full path when confirmed)*

| Barcode | Isolate ID | Species | S1 | S2 | S3 | S4 | S5 | Notes |
|---------|------------|---------|----|----|----|----|-----|-------|
| barcode49 | F-Arl-23.2 | _F. proliferatum_ | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | Telomere ✅ antiSMASH ✅ CAZymes/BigScape/effectorome ✅ |
| barcode50 | F-22-6 | _F. fujikuroi_ | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | Telomere ✅ antiSMASH ✅ CAZymes/BigScape/effectorome ✅ |
| barcode51 | F-22-24 | _F. fujikuroi_ | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | Telomere ✅ antiSMASH ✅ CAZymes/BigScape/effectorome ✅ |
| barcode52 | F-22-6 | _F. fujikuroi_ | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | Telomere ✅ antiSMASH ✅ BUSCO 99.3% verified |
| barcode53 | F-23-5.2 | _F. proliferatum_ | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | Telomere ✅ antiSMASH ✅ CAZymes/BigScape/effectorome ✅ |
| barcode55 | F-23-2.3 | Put. _F. subglutinans_ | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | Telomere ✅ antiSMASH ✅ CAZymes/BigScape/effectorome ✅ |
| barcode56 | F-23-4.4 | _F. cerealis_ | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | Telomere ✅ antiSMASH ✅ [ref genome](https://www.ncbi.nlm.nih.gov/datasets/genome/GCA_054553065.1/) |
| barcode57 | Fg-23-1.3 | _F. graminearum_ | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | Telomere ✅ antiSMASH ✅ CAZymes/BigScape/effectorome ✅ |
| barcode58 | F-Arl-23.2b | _F. proliferatum_ | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | Telomere ✅ antiSMASH ✅ CAZymes/BigScape/effectorome ✅ |

#### BUSCO scores — hypocreales (job 20579367, 2026-04-29)

| Barcode | BUSCO % | Assembler |
|---------|---------|-----------|
| barcode49 | 99.2% | Flye |
| barcode50 | 99.2% | Flye |
| barcode51 | 99.3% | Flye |
| barcode52 | 99.3% ✅ verified | Flye |
| barcode53 | 99.2% | Flye |
| barcode55 | 99.2% | Flye |
| barcode56 | 99.2% | Flye |
| barcode57 | 99.2% | Flye |
| barcode58 | 99.1% | Flye |

#### S5 sub-stage completion — batch_2025-Feb

| Sub-stage | Status | Date | Notes |
|-----------|--------|------|-------|
| 5.1 Telomere | ✅ | 2026-05-27 | Interactive node; fixed in 10_telomere_search.sh |
| 5.2 antiSMASH | ✅ | 2026-07-22 | Job ID TBD |
| 5.3 CAZymes | ✅ | TBD | Job ID TBD — fill in from Atlas logs |
| 5.4 BigScape | ✅ | TBD | Job ID TBD — fill in from Atlas logs |
| 5.5 Secretome | ✅ | TBD | Job ID TBD |
| 5.6 Effectorome | ✅ | TBD | Job ID TBD — fill in from Atlas logs |

---

### batch_2025-Dec

**Sequencing date:** 2025-12-01
**Barlist:** [`batches/batch_2025-Dec/barlist.txt`](batches/batch_2025-Dec/barlist.txt)
**Manifest:** `config/manifests/batch_2025-Dec_manifest.tsv`
**Ceres working path:** `/90daydata/silage_microbiome/max_seq/jan_batch2_all_barcodes/`
**Permanent storage:** `/project/silage_microbiome/` *(fill in full path when confirmed)*

| Barcode | Isolate ID | Species | S1 | S2 | S3 | S4 | S5 | Notes |
|---------|------------|---------|----|----|----|----|-----|-------|
| barcode36 | F-22-12a | _F. sporotrichioides_ | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | All S5 complete |
| barcode37 | F-22-12b | _F. sporotrichioides_ | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | All S5 complete |
| barcode38 | Fg-22-214.4 | _F. graminearum_ | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | All S5 complete |
| barcode39 | Fg-23-10 | _F. graminearum_ | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | All S5 complete |
| barcode40 | F-Arl-23.6 | _F. proliferatum_ | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | All S5 complete |
| barcode41 | Fg-23-7.2 | _F. graminearum_ | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | All S5 complete |
| barcode42 | F-23-8.10 | _F. proliferatum_ | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | All S5 complete |
| barcode43 | Fg-23-8.6 | _F. graminearum_ | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | All S5 complete |
| barcode44 | F-25-8710-1 | Put. _F. ipomoea_ | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | All S5 complete |
| barcode45 | F-23-8710-3 | _F. proliferatum_ | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | All S5 complete |

#### BUSCO scores — hypocreales (job 20526945, 2026-04-21)

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

#### S5 sub-stage completion — batch_2025-Dec

| Sub-stage | Status | Date | Notes |
|-----------|--------|------|-------|
| 5.1 Telomere | ✅ | 2026-07-23 | Array job via 10_telomere_search.sh; job ID TBD |
| 5.2 antiSMASH | ✅ | TBD | Job ID TBD — fill in from Atlas logs |
| 5.3 CAZymes | ✅ | TBD | Job ID TBD — fill in from Atlas logs |
| 5.4 BigScape | ✅ | TBD | Job ID TBD — fill in from Atlas logs |
| 5.5 Secretome | ✅ | TBD | Job ID TBD |
| 5.6 Effectorome | ✅ | TBD | Job ID TBD — fill in from Atlas logs |

---

### batch_2026-May

**Sequencing date:** 2026-05
**Basecaller:** MinKNOW (pre-basecalled — Path 1 dual-path workflow)
**Manifest:** `config/manifests/batch_2026-May_manifest.tsv`
**Ceres working path:** `/90daydata/silage_microbiome/max_seq/batch_2026-May/`
**Atlas working path:** `/90daydata/silage_microbiome/Max_Batch3/`
**Permanent storage:** TBD

> Note: No separate barlist.txt — manifest is single source of truth (CHANGELOG v1.5)

| Barcode | Isolate ID | Species | S1 | S2 | S3 | S4 | S5 | Notes |
|---------|------------|---------|----|----|----|----|-----|-------|
| barcode01 | F-22-214.2 | _F. verticillioides_ | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | All stages complete |
| barcode02 | F-Arl-23.9 | _F. proliferatum_ | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | All stages complete |
| barcode04 | Fg-23-5.5 | _F. graminearum_ | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | All stages complete |
| barcode05 | F-23-1.1 | _F. annulatum_ | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | New species; used F_verticillioides_7600 protein evidence |
| barcode06 | Fg-23-4.7 | _F. graminearum_ | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | All stages complete |
| barcode07 | Fg-23-1.5 | _F. graminearum_ | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | All stages complete |
| barcode08 | F-23-3 | _F. sporotrichioides_ | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | All stages complete |

> Note: barcode03 absent — not sequenced in this batch.

#### BUSCO scores — hypocreales (job TBD, 2026-07-23)

| Barcode | BUSCO % | Assembler |
|---------|---------|-----------|
| barcode01 | TBD | Flye |
| barcode02 | TBD | Flye |
| barcode04 | TBD | Flye |
| barcode05 | TBD | Flye |
| barcode06 | TBD | Flye |
| barcode07 | TBD | Flye |
| barcode08 | TBD | Flye |

> Fill in from 07_busco_eval.sh job output logs.

#### S5 sub-stage completion — batch_2026-May

| Sub-stage | Status | Date | Notes |
|-----------|--------|------|-------|
| 5.1 Telomere | ✅ | 2026-07-23 | Array job via 10_telomere_search.sh; job ID TBD |
| 5.2 antiSMASH | ✅ | 2026-07-23 | Job ID TBD |
| 5.3 CAZymes | ✅ | 2026-07-23 | Job ID TBD |
| 5.4 BigScape | ✅ | TBD | Job ID TBD |
| 5.5 Secretome/IPRScan | ✅ | 2026-07-23 | Job ID TBD |
| 5.6 Effectorome | ✅ | 2026-07-28 | Job ID TBD |

---

### batch4_2026-Sep

**Sequencing date:** 2026-09
**Basecaller:** Self-basecalled on Atlas from POD5s — **Path 2** dual-path workflow
(corrects earlier "MinKNOW / Path 1" note — this batch never used MinKNOW)
**Manifest:** `config/manifests/batch4_2026-Sep_manifest.tsv`
**Ceres working path:** `/90daydata/silage_microbiome/max_seq/batch4_2026-Sep/` *(confirm path on Ceres)*
**Atlas working path:** TBD
**Permanent storage:** TBD

> Note: barcodes 77–80 absent — not sequenced in this batch.

| Barcode | Isolate ID | Species | S1 | S2 | S3 | S4 | S5 | Notes |
|---------|------------|---------|----|----|----|----|-----|-------|
| barcode73 | F-23-7.1 | _F. graminearum_ | 🟢 | 🟢 | 🟢 | 🔵 | 🔵 | S4: `09a_FUN_predict.sh` in progress. Telomere ✅ tracker ✅; antiSMASH not yet (predict incomplete) |
| barcode74 | F-22-9 | _F. annulatum_ | 🟢 | 🟢 | 🟢 | 🔵 | 🔵 | S4: `09c_FUN_annotate.sh` in progress. Telomere ✅ antiSMASH ✅ tracker ✅. New species; `F_verticillioides_7600` protein evidence used — predict succeeded but dedicated file still unconfirmed |
| barcode75 | F-22-262 | _F. subglutinans_ | 🟢 | 🟢 | 🟢 | 🔵 | 🔵 | S4: `09a_FUN_predict.sh` in progress. Telomere ✅ tracker ✅; antiSMASH not yet (predict incomplete) |
| barcode76 | F-23-8.10 | _F. graminearum_ | 🟢 | 🟢 | 🟢 | 🔵 | 🔵 | S4: `09c_FUN_annotate.sh` in progress. Telomere ✅ antiSMASH ✅ tracker ✅ |
| barcode81 | F-23-2.1 | _F. subglutinans_ | 🟢 | 🟢 | 🟢 | 🔵 | 🔵 | S4: `08_sort_earlgrey_mask.sh` in progress. Telomere ✅ tracker ✅ (assumed — confirm); antiSMASH not yet reached |
| barcode82 | F-22-12a | _F. sporotrichioides_ | 🟢 | 🟢 | 🟢 | 🔵 | 🔵 | S4: `09c_FUN_annotate.sh` in progress. Telomere ✅ antiSMASH ✅ tracker ✅ |
| barcode83 | F-22-214.2 | _F. verticillioides_ | 🟢 | 🟢 | 🟢 | 🔵 | 🔵 | S4: `09c_FUN_annotate.sh` in progress. Telomere ✅ antiSMASH ✅ tracker ✅ |
| barcode84 | F-22-24 | _F. fujikuroi_ | 🟢 | 🟢 | 🟢 | 🔵 | 🔵 | S4: `09c_FUN_annotate.sh` in progress. Telomere ✅ antiSMASH ✅ tracker ✅ |

> Telomere/tracker scope for barcode81 marked "assumed" — inferred from it
> having an assembly (telomere and the contig tracker only need that), not
> confirmed against logs. Verify and correct if it didn't actually run yet.

---

## Completed isolates — permanent storage index

| Batch | Isolates | Permanent storage path | Notes |
|-------|----------|----------------------|-------|
| batch_2025-Feb | 9 | `/project/silage_microbiome/` *(fill in full path)* | Moved; path TBD |
| batch_2025-Dec | 10 | `/project/silage_microbiome/` *(fill in full path)* | Moved; path TBD |
| batch_2026-May | 7 | TBD | Not yet moved |

---

## Known issues by isolate

| Barcode | Isolate | Issue | Status |
|---------|---------|-------|--------|
| barcode52 | F-22-6 | BUSCO score inferred (99.3%) | ✅ Verified 99.3% |
| *(wtdbg2 trial)* | unknown | Trial barcode not recorded — locate on Ceres | ⚪ Open |
| barcode05 | F-23-1.1 | _F. annulatum_ — protein evidence not explicitly confirmed; `F_verticillioides_7600` used | ⚪ Verify |
| barcode74 | F-22-9 | _F. annulatum_ (batch4) — same as barcode05; `F_verticillioides_7600` used, predict succeeded (2026-09) | 🔵 Works operationally — dedicated protein evidence file still unconfirmed |

---

## Protein evidence file mapping

| Species | Protein evidence file | Basis |
|---------|----------------------|-------|
| _F. graminearum_ | `F_graminearum_PH1_proteins.faa` | Reference strain PH-1 |
| _F. sporotrichioides_ | `F_graminearum_PH1_proteins.faa` | Closest available |
| _F. proliferatum_ | `F_verticillioides_7600_proteins.faa` | Closest available |
| _F. verticillioides_ | `F_verticillioides_7600_proteins.faa` | Reference strain 7600 |
| _F. fujikuroi_ | `F_verticillioides_7600_proteins.faa` | Closest available |
| _F. subglutinans_ | `F_verticillioides_7600_proteins.faa` | Closest available |
| _F. annulatum_ | `F_verticillioides_7600_proteins.faa` | No dedicated file; verify |
| _F. cerealis_ | TBD | Check PROTEIN_EVIDENCE_DIR |
| _F. ipomoea_ | TBD | Check PROTEIN_EVIDENCE_DIR |
| _F. sporotrichioides_ | `F_graminearum_PH1_proteins.faa` | Closest available |

---

## Assembler decisions

| Batch | Assembler | Reason |
|-------|-----------|--------|
| batch_2025-Feb | Flye (all) | wtdbg2 trialed on 1 barcode; lower contiguity |
| batch_2025-Dec | Flye (all) | wtdbg2 not used |
| batch_2026-May | Flye (all) | Standard pipeline |
| batch4_2026-Sep | Flye (all) | Standard pipeline; assembly complete for all 8, now in S4 |

---

*Last updated: Sep 23, 2026*
