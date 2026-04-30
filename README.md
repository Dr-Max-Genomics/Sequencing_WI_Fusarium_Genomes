# Fusarium Whole Genome Sequencing Pipeline

A bioinformatics pipeline for whole genome sequencing and annotation of *Fusarium* species
using Oxford Nanopore long-read sequencing data on USDA SCINet's Ceres and Atlas HPC clusters.

**Maintainer:** Maxwell Chibuogwu (Dr. Max), Postdoctoral Fellow — USDA-ARS DFRC, Madison, WI
**Project:** Wisconsin *Fusarium* Isolate Genomics
**Contact:** maxwell.chibuogwu@usda.gov

> Isolates are sequenced and processed in batches over time.
> For the current status of each isolate, see [`BATCHES.md`](BATCHES.md).
> For a session-by-session run log, see [`PROGRESS.md`](PROGRESS.md).
> For pipeline version history and parameter changes, see [`CHANGELOG.md`](CHANGELOG.md).

---

## Table of contents

1. [Overview](#1-overview)
2. [Repository layout](#2-repository-layout)
3. [Prerequisites](#3-prerequisites)
4. [Quick start](#4-quick-start)
5. [Pipeline stages](#5-pipeline-stages)
   - [Stage 1 — Data preprocessing](#stage-1--data-preprocessing)
   - [Stage 2 — Genome assembly](#stage-2--genome-assembly)
   - [Stage 3 — Assembly evaluation](#stage-3--assembly-evaluation)
   - [Stage 4 — Genome annotation](#stage-4--genome-annotation)
   - [Stage 5 — Genome-wide analyses](#stage-5--genome-wide-analyses)
6. [Configuration](#6-configuration)
7. [The batch manifest](#7-the-batch-manifest)
8. [Running on a new batch](#8-running-on-a-new-batch)
9. [Testing a single array task](#9-testing-a-single-array-task)
10. [Output files](#10-output-files)
11. [SLURM resource reference](#11-slurm-resource-reference)
12. [Known issues and workarounds](#12-known-issues-and-workarounds)
13. [Troubleshooting](#13-troubleshooting)
14. [Citation](#14-citation)

---

## 1. Overview

This pipeline takes raw Oxford Nanopore basecalled reads (or POD5 files basecalled via
Atlas GPU) from barcoded *Fusarium* isolates and produces annotated genome assemblies.
Isolates are processed in batches and the pipeline is designed to resume cleanly at any
stage for any subset of barcodes.

**Genome size:** ~45–55 Mb (typical for *Fusarium* spp.)
**Target coverage:** 100×
**Minimum read length:** 500 bp
**Basecalling:** Dorado, SUP model recommended

### Pipeline at a glance

```
POD5 files from sequencer
        │
        ▼
Raw basecalled reads (barcoded)
        │
        ▼
Stage 1 — Preprocessing
        ├── 1.1  Concatenate per-barcode fastq.gz files
        ├── 1.2  Remove duplicate reads (seqkit rmdup)
        ├── 1.3  Trim ONT adapters (Porechop)
        ├── 1.4  Filter reads < 500 bp (NanoFilt)
        └── 1.5  QC plots and stats (NanoPlot)
        │
        ▼
Stage 2 — Genome assembly
        └── Flye (recommended) or wtdbg2
        │
        ▼
Stage 3 — Assembly evaluation
        ├── 3.1  BUSCO (hypocreales / sordariomycetes lineages)
        └── 3.2  Merqury, CRAQ, Quast
        │
        ▼
Stage 4 — Genome annotation        [scripts/07_ → 09c_]
        ├── 4.1  BUSCO evaluation on assembly          07_busco_eval.sh
        ├── 4.2  Sort + EarlGrey + Mask                08_sort_earlgrey_mask.sh
        ├── 4.3  Gene prediction (Funannotate predict) 09a_FUN_predict.sh
        ├── 4.4  Protein domain annotation (IPRScan)   09b_IPScan.sh
        └── 4.5  Functional annotation (Fun. annotate) 09c_FUN_annotate.sh
        │
        ▼
Stage 5 — Genome-wide analyses
        ├── 5.1  Telomere search (TelomereSearch.py)
        ├── 5.2  Secondary metabolite clusters (antiSMASH)
        ├── 5.3  CAZyme analysis (Funannotate / dbCAN)
        ├── 5.4  BGC networking (BiG-SCAPE)
        ├── 5.5  Secretome / protein analysis
        └── 5.6  Effectorome
                 ├── 5.6a  SignalP
                 └── 5.6b  Effector3.0
```

---

## 2. Repository layout

```
Sequencing_WI_Fusarium_Genomes/
├── README.md                    ← This file
├── BATCHES.md                   ← Isolate-level status tracker
├── PROGRESS.md                  ← Session-by-session run log
├── CHANGELOG.md                 ← Pipeline and parameter version history
│
├── config/
│   └── paths.sh                 ← All directory and DB path definitions
│
├── scripts/
│   ├── 01_concat.sh
│   ├── 02_seqkit_dedup.sh
│   ├── 03_porechop.sh
│   ├── 04_nanofilt.sh
│   ├── 05_nanoplot.sh
│   ├── 06_flye_assemble.sh
│   ├── 07_busco_eval.sh
│   ├── 08_sort_earlgrey_mask.sh
│   └── 09_Funannotate/
│       ├── 09a_FUN_predict.sh
│       ├── 09b_IPScan.sh
│       └── 09c_FUN_annotate.sh
│
├── batches/
│   ├── batch_2025-Feb/
│   │   ├── barlist.txt
│   │   └── sample_sheet.csv
│   ├── batch_2025-Dec/
│   │   ├── barlist.txt
│   │   └── sample_sheet.csv
│   └── [batch_YYYY-MM]/
│
├── Atlas Scripts in sequencing pipeline/   ← Legacy scripts
│
└── logs/                        ← Auto-populated by sbatch (gitignored)
```

> **Data never lives in this repo.** All `.fastq`, `.fasta`, and assembly files stay on
> Ceres/Atlas. Only manifests, scripts, and documentation are committed.

### On-disk layout (Ceres scratch — per batch)

```
/90daydata/silage_microbiome/max_seq/{BATCH_ID}/
├── 00_Raw_Data/
├── 01_QC/
├── 02_Trimming/
├── 03_Trimmed_Data/
├── 04_Summary_Plots/
├── 05_Genome_Assembly/
├── 06_Alignment_Polishing/
├── 07_Polished_Genome/
├── 08_Busco_Evaluation/
├── 09_EarlGrey/
├── 10_Mask/
├── 11a_FUN_Predict_Result/
│   └── FunAnnotate_{sampleID}/
│       ├── predict_misc/
│       ├── predict_results/      ← .proteins.fa input for IPRScan
│       ├── annotate_misc/        ← funannotate annotate output
│       └── annotate_results/     ← funannotate annotate output
├── 11b_InterProScan/             ← per-sample .xml files
├── 12a_AntiSMASH_gbk/            ← per-sample antiSMASH .gbk files
├── batch{N}_manifest.tsv         ← sample manifest for stages 07–09c
└── logs/
```

> Note: `funannotate annotate` outputs land inside `FunAnnotate_{sampleID}/` alongside
> the predict outputs — this is funannotate's expected behavior. There is no separate
> `11c_FUN_Annotate_Result/` directory. See CHANGELOG.md v1.4.

---

## 3. Prerequisites

### Environment setup (Ceres)

```bash
# Create conda environment (one-time)
module load miniconda
conda create --prefix /project/silage_microbiome/max.chi/seqenv
conda activate /project/silage_microbiome/max.chi/seqenv
conda install -c bioconda seqkit NanoFilt NanoPlot
```

### Module load reference

| Tool | Load command | Stage |
|------|-------------|-------|
| seqkit, NanoFilt, NanoPlot | `module load miniconda && source activate seqenv` | 1 |
| Porechop | `module unload miniconda && module load porechop` | 1 |
| Flye | `module load flye` | 2 |
| BUSCO | `module load busco5` | 3, 4.1 |
| EarlGrey | Apptainer: `${EARLGREY_SIF}` | 4.2 |
| Funannotate | `module load funannotate` | 4.2–4.5 |
| InterProScan | `module load interproscan` | 4.4 |

### Permanent DB and path locations

All paths defined in `config/paths.sh`. The key permanent locations:

| Variable | Path |
|----------|------|
| `PROJECT_ROOT` | `/project/silage_microbiome/max.chi/fusarium_sequencing` |
| `DB_ROOT` | `${PROJECT_ROOT}/DB_Databases` |
| `FUNANNOTATE_DB` | `${DB_ROOT}/funannotate_db` |
| `AUGUSTUS_CONFIG_PATH` | `${DB_ROOT}/augustus_config/config` |
| `BUSCO_DOWNLOADS` | `${DB_ROOT}/busco_downloads` |
| `EARLGREY_SIF` | `${PROJECT_ROOT}/Containers/earlgrey_dfam3.7_latest.sif` |
| `PROTEIN_EVIDENCE_DIR` | `${DB_ROOT}/protein_evidence` |

### Clone the repo on Ceres

```bash
cd /home/$USER
git clone https://github.com/Dr-Max-Genomics/Sequencing_WI_Fusarium_Genomes.git
cd Sequencing_WI_Fusarium_Genomes
```

---

## 4. Quick start

```bash
# 1. Start an interactive session (never run jobs on the login node)
srun -A silage_microbiome -N 1 -n 32 -p ceres -t 1-0 --pty bash

# 2. Source paths for your batch
export PROJECT_ROOT=/project/silage_microbiome/max.chi/fusarium_sequencing
source ${PROJECT_ROOT}/config/paths.sh

# 3. Confirm manifest is present
cat ${BATCH_DIR}/batch1_manifest.tsv | head -3

# 4. Test task 1 before submitting full array
sbatch --array=1 scripts/08_sort_earlgrey_mask.sh

# 5. Check output, then submit full array
sbatch --array=2-9 scripts/08_sort_earlgrey_mask.sh

# 6. Monitor
squeue --me
```

---

## 5. Pipeline stages

### Stage 1 — Data preprocessing

#### 1.1 Concatenate

```bash
sbatch -A silage_microbiome -N 1 -n 4 --mem=300G -p ceres -t 1-0 \
  --wrap='cat *.fastq.gz > barcodeXX.fastq.gz'
```

#### 1.2 Deduplication

```bash
sbatch -A silage_microbiome -N 1 -n 70 --mem=900G -p ceres -t 1-0 \
  --wrap='while read in; do seqkit rmdup ${in}.fastq.gz -n \
  -o ${in}_D.fastq -D ${in}_derep_list.txt; done < barlist.txt'
```

#### 1.3 Adapter trimming (Porechop)

> ⚠️ Unload miniconda before loading Porechop — see [Known issues](#12-known-issues-and-workarounds).

```bash
module unload miniconda && module load porechop
sbatch -A silage_microbiome -N 1 -n 70 --mem=900G -p ceres -t 1-0 \
  --wrap='while read in; do porechop-runner.py -i ${in}.fastq.gz \
  -o PC_${in}.fastq -t 70; done < barlist.txt'
```

#### 1.4 Length filtering (NanoFilt)

```bash
sbatch -A silage_microbiome -N 1 -n 70 --mem=150G -p ceres -t 1-0 \
  --wrap='while read in; do NanoFilt -l 500 PC_${in}.fastq \
  > ${in}.fastq; done < barlist.txt'
```

#### 1.5 QC (NanoPlot)

```bash
sbatch -A silage_microbiome -N 1 -n 70 --mem=150G -p ceres -t 1-0 \
  --wrap='while read in; do NanoPlot --fastq ${in}.fastq \
  --raw --tsv_stats --N50 -o ${in}; done < barlist.txt'
```

---

### Stage 2 — Genome assembly (Flye)

```bash
sbatch -A silage_microbiome -N 1 -n 40 --mem=50G -p ceres -t 1-0 \
  --wrap='flye --nano-corr barcodeXX.fastq --threads 40 \
  --genome-size 50m --asm-coverage 100 --iterations 1 \
  --out-dir barcodeXX_flye_assembly'
```

---

### Stage 3 — Assembly evaluation

#### BUSCO (script — manifest-driven)

```bash
# Test task 1
sbatch --array=1 scripts/07_busco_eval.sh
# Full array
sbatch --array=2-9 scripts/07_busco_eval.sh
```
#### Option B: Bash driven

```bash
# Run BUSCO on the polished assembly.
bash scripts/07_busco_eval.sh
# Equivalent sbatch:
sbatch -A silage_microbiome -N 1 -n 20 --mem=40000 -p ceres -t 1:00:00 \
  --wrap='busco -i polishedXX_assembly.fasta \
  -o polishedXX_assembly_output_eval/busco \
  -l hypocreales \
  --mode genome -c 20 \
  --offline'

# -i: Input FASTA file.
# -o: Output directory name.
# -l: Lineage dataset to use (e.g., hypocreales for Fusarium).
# --mode: Type of analysis (genome, transcriptome, proteins).
# -c: Number of cores/threads.
# --offline: would make it possible to run busco offline - avoiding redownloads of databases
```

**Output:** The key output is the `short_summary.*.busco.txt`, which gives percentages for Complete, Fragmented, and Missing BUSCO genes.

---

### Stage 4 — Genome annotation

All annotation stages (4.2–4.5) are manifest-driven array jobs.
Always test task 1 before submitting the full array.

#### 4.2 Sort + EarlGrey + Mask

```bash
sbatch --array=1 scripts/08_sort_earlgrey_mask.sh     # test
sbatch --array=2-9 scripts/08_sort_earlgrey_mask.sh   # full
```
Three steps in one job per isolate:
- `funannotate sort` — filters contigs < 1000 bp, standardizes headers
- EarlGrey (Apptainer) — repeat element detection
- `funannotate mask` — soft-masks assembly using EarlGrey repeat library
- These steps identify transposable elements (TEs) to create a custom repeat library for soft masking; soft masking changes the nucleotides of transposable elements and repeats to lower case so they are skipped by the annotation. Hard masking on the other hand deletes the repeated elements.

#### Option B: Bash driven sorting -> Masking
```bash
funannotate sort -i polishedXX_assembly.fasta --minlen 1000 \
  -o barXX_assem_sort.fa
```
```bash
# Earl Grey is run via an apptainer (formerly singularity) container.
# Pull the container image first.
apptainer pull --disable-cache docker://tobybaril/earlgrey_dfam3.7:latest
# Run Earl Grey
export EARLGREY_SIF=earlgrey_dfam3.7_latest.sif
apptainer run $EARLGREY_SIF
earlGrey -g barXX_assem_sort.fa -s fcXX -t 20 -o TE_EarlGrey/

# -g: Input genome FASTA.
# -s: Species name.
# -t: Number of threads.
# -o: Output directory.
```
```bash
export AUGUSTUS_CONFIG_PATH   # set in config/params.env
funannotate mask -i barXX_assem_sort.fa -m repeatmodeler \
  -l fcXX-families.fa -o SM_Mask/assem_XX_masked.fa
```

#### 4.3 Gene prediction (Funannotate predict)

```bash
sbatch --array=1 scripts/09_Funannotate/09a_FUN_predict.sh
sbatch --array=2-9 scripts/09_Funannotate/09a_FUN_predict.sh
```

Species-aware: `fusarium_graminearum` seed used for *F. graminearum* and
*F. cerealis*; `fusarium` seed used for all others. Controlled via `case`
statement on `funannotate_species` field in manifest.

#### 4.4 InterProScan

```bash
sbatch --array=1 scripts/09_Funannotate/09b_IPScan.sh
sbatch --array=2-9 scripts/09_Funannotate/09b_IPScan.sh
```

Input: `predict_results/*.proteins.fa` per isolate
Output: `11b_InterProScan/{sample_id}.xml`

#### 4.5 Funannotate annotate

```bash
sbatch --array=1 scripts/09_Funannotate/09c_FUN_annotate.sh
sbatch --array=2-9 scripts/09_Funannotate/09c_FUN_annotate.sh
```

Input: predict directory + IPRScan XML + antiSMASH GBK
Output: `annotate_misc/` and `annotate_results/` inside the predict directory
(co-located by funannotate design — see CHANGELOG.md v1.4)

---

### Stage 5 — Genome-wide analyses

*(In development — update when scripts are finalized)*

| Sub-stage | Tool | Script |
|-----------|------|--------|
| 5.1 Telomere search | TelomereSearch.py | `10_Telomere_search.sh` |
| 5.2 Secondary metabolites | antiSMASH | TBD |
| 5.3 CAZymes | Funannotate / dbCAN | `11_CAZymes.sh` |
| 5.4 BGC networking | BiG-SCAPE | TBD |
| 5.5 Secretome | TBD | TBD |
| 5.6 Effectorome | SignalP + Effector3.0 | TBD |

---

## 6. Configuration

All paths and database locations are defined in `config/paths.sh`.
Set `PROJECT_ROOT` before sourcing:

```bash
export PROJECT_ROOT=/project/silage_microbiome/max.chi/fusarium_sequencing
source ${PROJECT_ROOT}/config/paths.sh
```

To switch batches, change `BATCH_ID` in `paths.sh`:

```bash
BATCH_ID="batch1_all_barcodes"    # batch_2025-Feb
BATCH_ID="jan_batch2_all_barcodes" # batch_2025-Dec
```

---

## 7. The batch manifest

Stages 07–09c are driven by a tab-separated manifest file
(`batch{N}_manifest.tsv`) located in `${BATCH_DIR}/`.
Each row is one isolate; the header row is skipped by the scripts.

### Column order

```
barcode  sample_id  assembly_file  busco_name  earlgrey_species  funannotate_name  funannotate_species  protein_evidence_file  antismash_file
```

### Example row

```
barcode49  Bar49FusArl  Bar49_polished.fasta  Bar49_busco  FusBar49  FunAnnotate_Bar49  Fusarium proliferatum  Fproliferatum_refseq.faa  FusBar49.scaffolds_antiSMASH.gbk
```

### Notes
- `earlgrey_species` is the species prefix used for EarlGrey output paths
- `funannotate_name` is the output directory name under `11a_FUN_Predict_Result/`
- `protein_evidence_file` must exist in `${PROTEIN_EVIDENCE_DIR}`
- `antismash_file` must exist in `${ANTISMASH_DIR}`
- Array task ID maps to manifest line: `LINE_NUM = SLURM_ARRAY_TASK_ID + 1` (skips header)

---

## 8. Running on a new batch

```bash
# 1. Create batch folder in repo
mkdir -p batches/batch_YYYY-MM

# 2. Add barlist.txt and sample_sheet.csv
nano batches/batch_YYYY-MM/barlist.txt
nano batches/batch_YYYY-MM/sample_sheet.csv

# 3. Update BATCH_ID in config/paths.sh

# 4. Create batch manifest on Ceres
nano ${BATCH_DIR}/batch{N}_manifest.tsv

# 5. Add new isolates to BATCHES.md with status ⚪

# 6. Commit
git add batches/batch_YYYY-MM/ BATCHES.md CHANGELOG.md
git commit -m "batch: add YYYY-MM — N isolates (barcodeXX–YY)"

# 7. Run stages in order, updating PROGRESS.md each session
```

---

## 9. Testing a single array task

Always test task 1 before submitting the full array:

```bash
# Submit task 1 only
sbatch --array=1 scripts/08_sort_earlgrey_mask.sh

# Check log
cat ${BATCH_DIR}/logs/sort_earlgrey_mask/[sample_id].log

# If successful, submit the rest
sbatch --array=2-9 scripts/08_sort_earlgrey_mask.sh
```

---

## 10. Output files

### Stage 1 — Preprocessing

| File | Description |
|------|-------------|
| `*_D.fastq` | Deduplicated reads |
| `*_derep_list.txt` | Removed duplicates log |
| `PC_*.fastq` | Adapter-trimmed reads |
| `*.fastq` | Length-filtered reads |
| `*/NanoPlot-report.html` | Per-barcode QC report |
| `*/NanoStats.tsv` | Per-barcode QC stats |

### Stage 2 — Assembly

| File | Description |
|------|-------------|
| `assembly.fasta` | Final genome assembly |
| `assembly_info.txt` | Contig statistics |
| `flye.log` | Flye run log |

### Stage 3 — Evaluation

| File | Description |
|------|-------------|
| `short_summary.*.busco.txt` | BUSCO completeness report |

### Stage 4 — Annotation

| File | Location | Description |
|------|----------|-------------|
| `{sample_id}_sort.fa` | `07_Polished_Genome/` | Sorted, filtered assembly |
| `*-families.fa` | `09_EarlGrey/` | EarlGrey repeat library |
| `{sample_id}_masked.fa` | `10_Mask/` | Soft-masked assembly |
| `*.proteins.fa` | `11a_.../predict_results/` | Predicted proteins (IPRScan input) |
| `*.gff3` | `11a_.../predict_results/` | Gene predictions |
| `{sample_id}.xml` | `11b_InterProScan/` | IPRScan output |
| `*.gff3` | `11a_.../annotate_results/` | Functionally annotated predictions |
| `*.gbk` | `11a_.../annotate_results/` | GenBank format |
| `*.tbl` | `11a_.../annotate_results/` | NCBI annotation table |

---

## 11. SLURM resource reference

| Stage | Script | CPUs | Memory | Time | Partition |
|-------|--------|------|--------|------|-----------|
| Deduplication | 02 | 70 | 300 GB | 1 day | ceres |
| Porechop | 03 | 70 | 150 GB | 1 day | ceres |
| NanoFilt/NanoPlot | 04–05 | 70 | 150 GB | 1 day | ceres |
| Flye assembly | 06 | 40 | 50 GB | 1 day | ceres |
| BUSCO evaluation | 07 | 8 | 40 GB | 1 hr | ceres |
| Sort+EarlGrey+Mask | 08 | 20 | 40 GB | 6 hrs | ceres |
| Funannotate predict | 09a | 20 | 80 GB | 1 day | ceres |
| InterProScan | 09b | 32 | 64 GB | 6 hrs | ceres |
| Funannotate annotate | 09c | 32 | 150 GB | 6 hrs | ceres |

**Interactive session:**

```bash
srun -A silage_microbiome -N 1 -n 32 -p ceres -t 1-0 --pty bash
```

**Job monitoring:**

```bash
squeue --me                       # running/queued jobs
scancel JOBID                     # cancel a job
cat ${BATCH_DIR}/logs/[step]/[sample].log  # per-sample log
```

---

## 12. Known issues and workarounds

### Porechop vs. miniconda module conflict

```bash
# Before Porechop:
module unload miniconda
module load porechop

# After Porechop:
module unload porechop
module load miniconda
source activate seqenv
```

### Augustus write permissions

```bash
mkdir -p ${DB_ROOT}/augustus_config/config
chmod -R 770 ${DB_ROOT}/augustus_config/config
```

### barlist.txt format

```bash
cat -A barlist.txt       # each line should end with $ not ^M$
dos2unix barlist.txt     # fix Windows line endings if needed
wc -l barlist.txt        # confirm expected number of barcodes
```

### /90daydata purge policy

Files on `/90daydata/` are purged after 90 days of no access. Before a batch
goes idle, copy final outputs to `/project/` and log the path in `BATCHES.md`.

### Funannotate annotate output location

`funannotate annotate` writes `annotate_misc/` and `annotate_results/` inside
the same directory as `predict_misc/` and `predict_results/`, regardless of
any `-o` flag. This is expected behavior. All annotate outputs are in
`11a_FUN_Predict_Result/FunAnnotate_{sampleID}/`. See CHANGELOG.md v1.4.

### SLURM #SBATCH header flags ignored

If `sbatch` ignores `#SBATCH` directives in a script, pass flags directly
on the command line:

```bash
sbatch -N 1 -n 32 --mem=64G -p ceres -t 6:00:00 --array=1-9 scripts/09b_IPScan.sh
```

---

## 13. Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `conda: command not found` | miniconda not loaded | `module load miniconda` |
| `porechop: ImportError` | miniconda still loaded | `module unload miniconda` first |
| Job disappears from queue immediately | Script syntax error | Check `logs/[step]/[sample].log` |
| Empty output `.fastq` | Wrong barlist path | Check `BARLIST` in `paths.sh` |
| `srun` hangs at prompt | Cluster at capacity | Reduce time or try off-peak |
| Augustus permission denied | Config dir not writable | `chmod -R 770 $AUGUSTUS_CONFIG_PATH` |
| Funannotate predict fails | `FUNANNOTATE_DB` not set | `source config/paths.sh` first |
| EarlGrey families.fa missing | Wrong `earlgrey_species` in manifest | Check manifest column 5 matches EarlGrey output naming |
| Manifest row read incorrectly | Tab vs space delimiter | Confirm TSV with `cat -A batch1_manifest.tsv` |
| Array task fails, others succeed | Per-sample input missing | Check per-sample log in `logs/[step]/[sample_id].log` |

---

## 14. Citation

If you use this pipeline, please cite the relevant tools:

- **Flye:** Kolmogorov et al. (2019) *Nature Biotechnology*
- **BUSCO:** Manni et al. (2021) *Molecular Biology and Evolution*
- **Funannotate:** Palmer & Stajich — https://github.com/nextgenusfs/funannotate
- **EarlGrey:** Baril & Imrie (2023)
- **NanoPlot / NanoFilt:** De Coster et al. (2018) *Bioinformatics*
- **Porechop:** Wick et al. — https://github.com/rrwick/Porechop
- **seqkit:** Shen et al. (2016) *PLOS ONE*
- **InterProScan:** Jones et al. (2014) *Bioinformatics*
- **antiSMASH:** Blin et al. (2023) *Nucleic Acids Research*
- **wtdbg2:** Ruan & Li (2020) *Nature Methods*

---

*For questions, open an issue on GitHub or contact Maxwell Chibuogwu.*
