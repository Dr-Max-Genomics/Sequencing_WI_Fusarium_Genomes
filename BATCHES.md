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
| `DONE` | All stages complete, outputs in permanent storage |

---

## Summary

| Batch | Isolates | S1 done | S2 done | S3 done | S4 done | Notes |
|-------|----------|---------|---------|---------|---------|-------|
| batch_2025-02 | 0 | 0 | 0 | 0 | 0 | ← replace with your first batch |
| **Total** | **0** | **0** | **0** | **0** | **0** | |

> Update the summary table counts whenever the detailed table below changes.

---

## Detailed isolate status

### batch_YYYY-MM
<!-- Copy this block for each new batch. Rename the heading to match the folder name. -->

**Sequencing date:** YYYY-MM-DD  
**Barlist:** [`batches/batch_YYYY-MM/barlist.txt`](batches/batch_YYYY-MM/barlist.txt)  
**Sample sheet:** [`batches/batch_YYYY-MM/sample_sheet.csv`](batches/batch_YYYY-MM/sample_sheet.csv)  
**Ceres data path:** `/90daydata/silage_microbiome/[path]/`  
**Permanent storage path:** `/project/silage_microbiome/[path]/` *(fill in when moved)*

| Barcode | Isolate ID | S1 | S2 | S3 | S4 | Notes |
|---------|------------|----|----|----|----|-------|
| barcodeXX | isolate_ID | ⚪ | ⚪ | ⚪ | ⚪ | |
| barcodeXX | isolate_ID | ⚪ | ⚪ | ⚪ | ⚪ | |

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

*Last updated: YYYY-MM-DD*
