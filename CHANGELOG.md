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
| `S1` | Preprocessing (concat → dedup → porechop → nanofilt → nanoplot) |
| `S2` | Genome assembly (Flye) |
| `S3` | Assembly evaluation (BUSCO — hypocreales) |
| `S4` | Genome annotation (sort → EarlGrey → mask → predict → IPRScan → annotate) |
| `S5` | Genome-wide analyses (telomere, antiSMASH, CAZymes, BigScape, effectorome) |
| `DONE` | All stages complete, in permanent storage |

---

## Summary

| Batch | Isolates | S1 | S2 | S3 | S4 | S5 | Notes |
|-------|----------|----|----|----|----|----|-------|
| batch_2025-Feb | 9 | 9 | 9 | 9 | 9 | 🔵 | Telomere done; CAZymes/antiSMASH pending |
| batch_2025-Dec | 10 | 10 | 10 | 10 | 10 | ⚪ | Telomere array ready to run |
| batch_2026-May | 7 | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | Starting S1 concatenation |
| **Total** | **26** | **19** | **19** | **19** | **19** | — | |

---

## Detailed isolate status

### batch_2025-Feb

**Sequencing date:** 2025-02-03
**Barlist:** [`batches/batch_2025-Feb/barlist.txt`](batches/batch_2025-Feb/barlist.txt)
**Manifest:** `batch1_manifest.tsv` at `/90daydata/silage_microbiome/max_seq/batch1_all_barcodes/`
**Ceres working path:** `/90daydata/silage_microbiome/max_seq/batch1_all_barcodes/`
**Permanent storage:** `/project/silage_microbiome/` *(fill in when moved)*

| Barcode | Isolate ID | Species | S1 | S2 | S3 | S4 | S5 | Notes |
|---------|------------|---------|----|----|----|----|-----|-------|
| barcode49 | F-Arl-23.2 | _F. proliferatum_ | 🟢 | 🟢 | 🟢 | 🟢 | 🔵 | Telomere ✅ |
| barcode50 | F-22-6 | _F. fujikuroi_ | 🟢 | 🟢 | 🟢 | 🟢 | 🔵 | Telomere ✅ |
| barcode51 | F-22-24 | _F. fujikuroi_ | 🟢 | 🟢 | 🟢 | 🟢 | 🔵 | Telomere ✅ |
| barcode52 | F-22-6 | _F. fujikuroi_ | 🟢 | 🟢 | 🟢 | 🟢 | 🔵 | Telomere ✅; ⚠️ verify BUSCO 99.3% |
| barcode53 | F-23-5.2 | _F. proliferatum_ | 🟢 | 🟢 | 🟢 | 🟢 | 🔵 | Telomere ✅ |
| barcode55 | F-23-2.3 | Put. _F. subglutinans_ | 🟢 | 🟢 | 🟢 | 🟢 | 🔵 | Telomere ✅ |
| barcode56 | F-23-4.4 | _F. cerealis_ | 🟢 | 🟢 | 🟢 | 🟢 | 🔵 | Telomere ✅; [ref genome](https://www.ncbi.nlm.nih.gov/datasets/genome/GCA_054553065.1/) |
| barcode57 | Fg-23-1.3 | _F. graminearum_ | 🟢 | 🟢 | 🟢 | 🟢 | 🔵 | Telomere ✅ |
| barcode58 | F-Arl-23.2b | _F. proliferatum_ | 🟢 | 🟢 | 🟢 | 🟢 | 🔵 | Telomere ✅ |

#### BUSCO scores — hypocreales (job 20579367, 2026-04-29)

| Barcode | BUSCO % | Assembler |
|---------|---------|-----------|
| barcode49 | 99.2% | Flye |
| barcode50 | 99.2% | Flye |
| barcode51 | 99.3% | Flye |
| barcode52 | 99.3% ⚠️ | Flye |
| barcode53 | 99.2% | Flye |
| barcode55 | 99.2% | Flye |
| barcode56 | 99.2% | Flye |
| barcode57 | 99.2% | Flye |
| barcode58 | 99.1% | Flye |

---

### batch_2025-Dec

**Sequencing date:** 2025-12-01
**Barlist:** [`batches/batch_2025-Dec/barlist.txt`](batches/batch_2025-Dec/barlist.txt)
**Manifest:** *(create batch2_manifest.tsv before next run)*
**Ceres working path:** `/90daydata/silage_microbiome/max_seq/jan_batch2_all_barcodes/`
**Permanent storage:** `/project/silage_microbiome/` *(fill in when moved)*

| Barcode | Isolate ID | Species | S1 | S2 | S3 | S4 | S5 | Notes |
|---------|------------|---------|----|----|----|----|-----|-------|
| barcode36 | F-22-12a | _F. sporotrichioides_ | 🟢 | 🟢 | 🟢 | 🟢 | ⚪ | Telomere pending |
| barcode37 | F-22-12b | _F. sporotrichioides_ | 🟢 | 🟢 | 🟢 | 🟢 | ⚪ | Telomere pending |
| barcode38 | Fg-22-214.4 | _F. graminearum_ | 🟢 | 🟢 | 🟢 | 🟢 | ⚪ | Telomere pending |
| barcode39 | Fg-23-10 | _F. graminearum_ | 🟢 | 🟢 | 🟢 | 🟢 | ⚪ | Telomere pending |
| barcode40 | F-Arl-23.6 | _F. proliferatum_ | 🟢 | 🟢 | 🟢 | 🟢 | ⚪ | Telomere pending |
| barcode41 | Fg-23-7.2 | _F. graminearum_ | 🟢 | 🟢 | 🟢 | 🟢 | ⚪ | Telomere pending |
| barcode42 | F-23-8.10 | _F. proliferatum_ | 🟢 | 🟢 | 🟢 | 🟢 | ⚪ | Telomere pending |
| barcode43 | Fg-23-8.6 | _F. graminearum_ | 🟢 | 🟢 | 🟢 | 🟢 | ⚪ | Telomere pending |
| barcode44 | F-25-8710-1 | Put. _F. ipomoea_ | 🟢 | 🟢 | 🟢 | 🟢 | ⚪ | Telomere pending |
| barcode45 | F-23-8710-3 | _F. proliferatum_ | 🟢 | 🟢 | 🟢 | 🟢 | ⚪ | Telomere pending |

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

---

### batch_2026-May

**Sequencing date:** 2026-05
**Basecaller:** MinKNOW (pre-basecalled — starting at S1 concatenation)
**Manifest:** `batch3_manifest.tsv` at `/90daydata/silage_microbiome/max_seq/batch_2026-May/`
**Ceres working path:** `/90daydata/silage_microbiome/max_seq/batch_2026-May/`
**Permanent storage:** TBD

> Note: No separate barlist.txt — manifest is single source of truth (CHANGELOG v1.5)

| Barcode | Isolate ID | Species | S1 | S2 | S3 | S4 | S5 | Notes |
|---------|------------|---------|----|----|----|----|-----|-------|
| barcode01 | F-22-214.2 | _F. verticillioides_ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | |
| barcode02 | F-Arl-23.9 | _F. proliferatum_ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | |
| barcode04 | Fg-23-5.5 | _F. graminearum_ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | |
| barcode05 | F-23-1.1 | _F. annulatum_ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚠️ New species — verify protein evidence |
| barcode06 | Fg-23-4.7 | _F. graminearum_ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | |
| barcode07 | Fg-23-1.5 | _F. graminearum_ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | |
| barcode08 | F-23-3 | _F. sporotrichioides_ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | |

> Note: barcode03 absent — not sequenced in this batch.

---

## Completed isolates — permanent storage index

| Isolate ID | Barcode | Batch | Assembly path | Annotation path | BUSCO % |
|------------|---------|-------|--------------|----------------|---------|
| *(pending — both completed batches awaiting storage move)* | | | | | |

---

## Known issues by isolate

| Barcode | Isolate | Issue | Status |
|---------|---------|-------|--------|
| barcode52 | F-22-6 | BUSCO score inferred (99.3%) — verify | ⚪ Open |
| *(wtdbg2 trial)* | unknown | Trial barcode not recorded — locate on Ceres | ⚪ Open |
| barcode05 | F-23-1.1 | _F. annulatum_ — new species; verify protein evidence file | ⚪ Open |

---

## Assembler decisions

| Batch | Assembler | Reason |
|-------|-----------|--------|
| batch_2025-Feb | Flye (all) | wtdbg2 trialed on 1 barcode; lower contiguity |
| batch_2025-Dec | Flye (all) | wtdbg2 not used |
| batch_2026-May | Flye (planned) | Standard pipeline |

---

*Last updated: 2026-05-27*
