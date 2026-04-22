# Isolate batch tracker

This file tracks the processing status of every *Fusarium* isolate across all sequencing batches.
It is the single source of truth for "what has been done to which isolate."

> Update this file whenever an isolate advances to a new stage.
> Commit it alongside `PROGRESS.md` after each work session.
> For session-level notes on what you ran, see [`PROGRESS.md`](PROGRESS.md).

---

## How to read this file

**Batch folders** group isolates by when they were sequenced (`batches/YYYY-MM/`).
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
| `S2` | Genome assembly (Flye or wtdbg2) |
| `S3` | Assembly evaluation (BUSCO) |
| `S4` | Genome annotation (EarlGrey → Funannotate) |
| `S5` | Genome-wide Analyses (Telomere Search, AntiSMASH, CAZyme) |
| `DONE` | All stages complete, outputs in permanent storage |

---

## Summary

| Batch | Isolates | S1 done | S2 done | S3 done | S4 done | S5 done | Notes | 
|-------|----------|---------|---------|---------|---------|-------|-------|
| batch_2025-Feb | 9 | 9 | 9 | 9 | 4 | 0 | Run IPScan and Annotation |
| batch_2025-Dec | 10 | 10 | 10 | 10 | 6 | 0 | Complete IPScan and Annotation for remaining 8 samples |
| batch_2026-XX | 0 | 0 | 0 | 0 | 0 | 0 |  |
| **Total** | **0** | **0** | **0** | **0** | **0** | **0** | |

> Update the summary table counts whenever the detailed table below changes.

---

## Detailed isolate status

### batch_2025-Feb
<!-- Copy this block for each new batch. Rename the heading to match the folder name. -->

**Sequencing date:** 2025-02-03  
**Sample sheet:** [`batches/batch_YYYY-MM/sample_sheet.csv`](batches/batch_YYYY-MM/sample_sheet.csv)  
**Ceres data path:** `/90daydata/silage_microbiome/[path]/`  
**Permanent storage path:** `/project/silage_microbiome/[path]/` *(fill in when moved)*

| Barcode | Isolate ID | Species |S1 | S2 | S3 | S4 | S5 | Notes |
|---------|------------|---------|----|----|----|----|----|-------|
| barcode49 | isolate_F-Arl-23.2 | _F. proliferatum_ | 🟢 | 🟢 | 🟢 | ⚪ | ⚪ | |
| barcode50 | isolate_F-22-6 | _F. fujikuroi_ | 🟢 | 🟢 | 🟢 | ⚪ | ⚪ | |
| barcode51 | isolate_F-22-24 | _F. fujikuroi_ | 🟢 | 🟢 | 🟢 | ⚪ | ⚪ | |
| barcode52 | isolate_F-22-6 | _F. fujikuroi_ | 🟢 | 🟢 | 🟢 | ⚪ | ⚪ | |
| barcode53 | isolate_F-23-5.2 | _F. proliferatum_ | 🟢 | 🟢 | 🟢 | ⚪ | ⚪ | |
| barcode55 | isolate_F-23-2.3 | Put. _F. subglutinans_ | 🟢 | 🟢 | 🟢 | ⚪ | ⚪ | |
| barcode56 | isolate_F-23-4.4 | _F. cerealis_ | 🟢 | 🟢 | 🟢 | 🔵 | ⚪ | [Published Reference Genome](https://www.ncbi.nlm.nih.gov/datasets/genome/GCA_054553065.1/) |
| barcode57 | isolate_Fg-23-1.3 | _F. graminearum_ | 🟢 | 🟢 | 🟢 | ⚪ | ⚪ | |
| barcode58 | isolate_F-Arl-23.2b | _F. proliferatum_ | 🟢 | 🟢 | 🟢 | ⚪ | ⚪ | |

### batch_2025-Dec

**Sequencing date:** 2025-12-01  
**Sample sheet:** [`batches/batch_YYYY-MM/sample_sheet.csv`](batches/batch_YYYY-MM/sample_sheet.csv)  
**Ceres data path:** `/90daydata/silage_microbiome/[path]/`  
**Permanent storage path:** `/project/silage_microbiome/[path]/` *(fill in when moved)*

| Barcode | Isolate ID | Species | S1 | S2 | S3 | S4 | S5 | Notes |
|---------|------------|---------|----|----|----|----|----|-------|
| barcode36 | isolate_F-22-12a | _F. sporotrichioides_ | 🟢 | 🟢 | 🟢 | 🔵 | ⚪ | |
| barcode37 | isolate_F-22-12b | _F. sporotrichioides_ | 🟢 | 🟢 | 🟢 | 🔵 | ⚪ | |
| barcode38 | isolate_Fg-22-214.4 | _F. graminearum_ | 🟢 | 🟢 | 🟢 | 🔵 | ⚪ | |
| barcode39 | isolate_Fg-23-10 | _F. graminearum_ | 🟢 | 🟢 | 🟢 | 🔵 | ⚪ | |
| barcode40 | isolate_F-Arl-23.6 |isolate_F-Arl-23.2 | 🟢 | 🟢 | 🟢 | 🔵 | ⚪ | |
| barcode41 | isolate_Fg-23-7.2 | _F. graminearum_ | 🟢 | 🟢 | 🟢 | 🔵 | ⚪ | |
| barcode42 | isolate_F-23-8.10 | _F. proliferatum_ | 🟢 | 🟢 | 🟢 | 🔵 | ⚪ | |
| barcode43 | isolate_Fg-23-8.6 | _F. graminearum_ | 🟢 | 🟢 | 🟢 | 🔵 | ⚪ | |
| barcode44 | isolate_F-25-8710-1 | Put. _F. ipomoea_ | 🟢 | 🟢 | 🟢 | 🔵 | ⚪ | |
| barcode45 | isolate_F-23-8710-3 | _F. proliferatum_ | 🟢 | 🟢 | 🟢 | 🔵 | ⚪ | |

### batch_2026-XXX

**Sequencing date:** 2026-XX-XX  
**Sample sheet:** [`batches/batch_YYYY-MM/sample_sheet.csv`](batches/batch_YYYY-MM/sample_sheet.csv)  
**Ceres data path:** `/90daydata/silage_microbiome/[path]/`  
**Permanent storage path:** `/project/silage_microbiome/[path]/` *(fill in when moved)*

| Barcode | Isolate ID | S1 | S2 | S3 | S4 | S5 | Notes |
|---------|------------|----|----|----|----|----|-------|
| barcodeXX | isolate_ID | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | |
| barcodeXX | isolate_ID | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | |
| barcodeXX | isolate_ID | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | |
| barcodeXX | isolate_ID | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | |
| barcodeXX | isolate_ID | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | |
| barcodeXX | isolate_ID | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | |
| barcodeXX | isolate_ID | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | |
| barcodeXX | isolate_ID | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | |
| barcodeXX | isolate_ID | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | |
| barcodeXX | isolate_ID | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | |

---

## Completed isolates — permanent storage index

Once an isolate reaches `DONE`, log its final output location here so it can be found
after `/90daydata/` is purged.

| Isolate ID | Barcode | Batch | Assembly path | Annotation path | BUSCO score |
|------------|---------|-------|--------------|----------------|-------------|
| *(none yet)* | | | | | |

---

## Known issues by isolate

Log any barcode-specific problems here so they don't get lost between sessions.

| Barcode | Isolate ID | Issue | Status |
|---------|------------|-------|--------|
| *(none yet)* | | | |

---

## Assembler decisions

When you choose wtdbg2 over Flye (or vice versa) for a specific isolate, document why here
so the decision is traceable.

| Barcode | Isolate ID | Assembler used | Reason |
|---------|------------|---------------|--------|
| *(none yet)* | | | |

---

*Last updated: 2026-02-10*
