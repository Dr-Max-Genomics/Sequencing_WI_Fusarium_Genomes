# Isolate batch tracker

This file tracks the processing status of every *Fusarium* isolate across all sequencing batches.
It is the single source of truth for "what has been done to which isolate."

> Update this file whenever an isolate advances to a new stage.
> Commit alongside `PROGRESS.md` after each work session.
> For session-level notes on what you ran, see [`PROGRESS.md`](PROGRESS.md).

---

## How to read this file

**Batch folders** group isolates by when they were sequenced.
**Status** reflects the furthest pipeline stage completed for each isolate.

### Status key

| Symbol | Meaning |
|--------|---------|
| ⚪ | Not started |
| 🔵 | In progress |
| 🟢 | Complete |
| 🔴 | Blocked / failed — see notes |
| ⏸️ | On hold (intentional pause) |

### Stage codes

| Code | Stage |
|------|-------|
| `S1` | Preprocessing (concat → dedup → porechop → nanofilt → nanoplot) |
| `S2` | Genome assembly (Flye) |
| `S3` | Assembly evaluation (BUSCO — hypocreales) |
| `S4` | Genome annotation (sort → EarlGrey → mask → predict → IPRScan → annotate) |
| `S5` | Genome-wide analyses (telomere search, antiSMASH, CAZymes, BigScape, effectorome) |
| `DONE` | All stages complete, outputs in permanent storage |

---

## Summary

| Batch | Isolates | S1 | S2 | S3 | S4 | S5 | Notes |
|-------|----------|----|----|----|----|----|-------|
| batch_2025-Feb | 9 | 9 | 9 | 9 | 9 | 0 | S4 complete 2026-04-29 |
| batch_2025-Dec | 10 | 10 | 10 | 10 | 10 | 0 | S4 complete 2026-04-21 |
| batch_2026-XX | 0 | 0 | 0 | 0 | 0 | 0 | Future batch |
| **Total** | **19** | **19** | **19** | **19** | **19** | **0** | |

> Update summary counts whenever the detailed table below changes.

---

## Detailed isolate status

### batch_2025-Feb

**Sequencing date:** 2025-02-03
**Barlist:** [`batches/batch_2025-Feb/barlist.txt`](batches/batch_2025-Feb/barlist.txt)
**Sample sheet:** [`batches/batch_2025-Feb/sample_sheet.csv`](batches/batch_2025-Feb/sample_sheet.csv)
**Manifest:** `batch1_manifest.tsv` (on Ceres at `/90daydata/silage_microbiome/max_seq/batch1_all_barcodes/`)
**Ceres working path:** `/90daydata/silage_microbiome/max_seq/batch1_all_barcodes/`
**Permanent storage path:** `/project/silage_microbiome/` *(fill in when moved)*

| Barcode | Isolate ID | Species | S1 | S2 | S3 | S4 | S5 | Notes |
|---------|------------|---------|----|----|----|----|-----|-------|
| barcode49 | F-Arl-23.2 | _F. proliferatum_ | 🟢 | 🟢 | 🟢 | 🟢 | ⚪ | |
| barcode50 | F-22-6 | _F. fujikuroi_ | 🟢 | 🟢 | 🟢 | 🟢 | ⚪ | |
| barcode51 | F-22-24 | _F. fujikuroi_ | 🟢 | 🟢 | 🟢 | 🟢 | ⚪ | |
| barcode52 | F-22-6 | _F. fujikuroi_ | 🟢 | 🟢 | 🟢 | 🟢 | ⚪ | |
| barcode53 | F-23-5.2 | _F. proliferatum_ | 🟢 | 🟢 | 🟢 | 🟢 | ⚪ | |
| barcode55 | F-23-2.3 | Put. _F. subglutinans_ | 🟢 | 🟢 | 🟢 | 🟢 | ⚪ | |
| barcode56 | F-23-4.4 | _F. cerealis_ | 🟢 | 🟢 | 🟢 | 🟢 | ⚪ | [Published ref genome](https://www.ncbi.nlm.nih.gov/datasets/genome/GCA_054553065.1/) |
| barcode57 | Fg-23-1.3 | _F. graminearum_ | 🟢 | 🟢 | 🟢 | 🟢 | ⚪ | |
| barcode58 | F-Arl-23.2b | _F. proliferatum_ | 🟢 | 🟢 | 🟢 | 🟢 | ⚪ | |

#### BUSCO scores — hypocreales lineage

| Barcode | BUSCO % | Job (2026-04-29 rerun) |
|---------|---------|------------------------|
| barcode49 | 99.2% | 20579367 |
| barcode50 | 99.3% | 20579367 |
| barcode51 | 99.4% | 20579367 |
| barcode52 | 99.4% | 20579367 |
| barcode53 | 99.3% | 20579367 |
| barcode55 | 99.3% | 20579367 |
| barcode56 | 99.4% | 20579367 |
| barcode57 | 99.3% | 20579367 |
| barcode58 | 99.3% | 20579367 |

---

### batch_2025-Dec

**Sequencing date:** 2025-12-01
**Barlist:** [`batches/batch_2025-Dec/barlist.txt`](batches/batch_2025-Dec/barlist.txt)
**Sample sheet:** [`batches/batch_2025-Dec/sample_sheet.csv`](batches/batch_2025-Dec/sample_sheet.csv)
**Manifest:** *(create batch2_manifest.tsv before next S4 run if needed)*
**Ceres working path:** `/90daydata/silage_microbiome/max_seq/jan_batch2_all_barcodes/`
**Permanent storage path:** `/project/silage_microbiome/` *(fill in when moved)*

| Barcode | Isolate ID | Species | S1 | S2 | S3 | S4 | S5 | Notes |
|---------|------------|---------|----|----|----|----|-----|-------|
| barcode36 | F-22-12a | _F. sporotrichioides_ | 🟢 | 🟢 | 🟢 | 🟢 | ⚪ | |
| barcode37 | F-22-12b | _F. sporotrichioides_ | 🟢 | 🟢 | 🟢 | 🟢 | ⚪ | |
| barcode38 | Fg-22-214.4 | _F. graminearum_ | 🟢 | 🟢 | 🟢 | 🟢 | ⚪ | |
| barcode39 | Fg-23-10 | _F. graminearum_ | 🟢 | 🟢 | 🟢 | 🟢 | ⚪ | |
| barcode40 | F-Arl-23.6 | _F. proliferatum_ | 🟢 | 🟢 | 🟢 | 🟢 | ⚪ | |
| barcode41 | Fg-23-7.2 | _F. graminearum_ | 🟢 | 🟢 | 🟢 | 🟢 | ⚪ | |
| barcode42 | F-23-8.10 | _F. proliferatum_ | 🟢 | 🟢 | 🟢 | 🟢 | ⚪ | |
| barcode43 | Fg-23-8.6 | _F. graminearum_ | 🟢 | 🟢 | 🟢 | 🟢 | ⚪ | |
| barcode44 | F-25-8710-1 | Put. _F. ipomoea_ | 🟢 | 🟢 | 🟢 | 🟢 | ⚪ | |
| barcode45 | F-23-8710-3 | _F. proliferatum_ | 🟢 | 🟢 | 🟢 | 🟢 | ⚪ | |

#### BUSCO scores — hypocreales lineage

| Barcode | BUSCO % | Job (2026-04-21) |
|---------|---------|------------------|
| barcode36 | 99.4% | 20526945 |
| barcode37 | 99.4% | 20526945 |
| barcode38 | 99.3% | 20526945 |
| barcode39 | 99.3% | 20526945 |
| barcode40 | 99.4% | 20526945 |
| barcode41 | 99.3% | 20526945 |
| barcode42 | 99.3% | 20526945 |
| barcode43 | 99.3% | 20526945 |
| barcode44 | 99.3% | 20526945 |
| barcode45 | 99.3% | 20526945 |

---

### batch_2026-XXX

**Sequencing date:** TBD
**Ceres data path:** TBD
**Permanent storage path:** TBD

| Barcode | Isolate ID | Species | S1 | S2 | S3 | S4 | S5 | Notes |
|---------|------------|---------|----|----|----|----|-----|-------|
| barcodeXX | isolate_ID | | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | |

---

## Completed isolates — permanent storage index

Once an isolate reaches `DONE`, log its final output location here.

| Isolate ID | Barcode | Batch | Assembly path | Annotation path | BUSCO % |
|------------|---------|-------|--------------|----------------|---------|
| *(none yet — both batches pending storage move)* | | | | | |

---

## Known issues by isolate

| Barcode | Isolate ID | Issue | Status |
|---------|------------|-------|--------|
| barcode52 | F-22-6 | BUSCO score inferred (99.3%) — verify against actual output | ⚪ Open |
| *(wtdbg2 trial)* | unknown | Barcode trialed with wtdbg2 not recorded — locate on Ceres | ⚪ Open |

---

## Assembler decisions

| Barcode | Isolate ID | Assembler used | Reason |
|---------|------------|---------------|--------|
| All (batch_2025-Feb) | all | Flye | wtdbg2 trialed on 1 barcode; lower contiguity — Flye selected |
| All (batch_2025-Dec) | all | Flye | wtdbg2 not used this batch |

---

*Last updated: 2026-04-29*
