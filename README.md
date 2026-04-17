# Fusarium Whole Genome Sequencing Pipeline

A bioinformatics pipeline for whole genome sequencing and annotation of *Fusarium* species
using Oxford Nanopore long-read sequencing data on USDA SCINet's Ceres and Atlas HPC clusters.

**Maintainer:** Maxwell Chibuogwu (Dr. Max), Postdoctoral Fellow — USDA-ARS DFRC, Madison, WI  
**Project:** Wisconsin *Fusarium* Isolate Genomics  
**Contact:** [your.email@usda.gov]

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
6. [Configuration](#6-configuration)
7. [Running on a new batch](#7-running-on-a-new-batch)
8. [Testing a single barcode](#8-testing-a-single-barcode)
9. [Output files](#9-output-files)
10. [SLURM resource reference](#10-slurm-resource-reference)
11. [Known issues and workarounds](#11-known-issues-and-workarounds)
12. [Troubleshooting](#12-troubleshooting)
13. [Citation](#13-citation)

---

## 1. Overview

This pipeline takes raw Oxford Nanopore basecalled reads (or POD5s to be basecalled using Atlas' GPU) from barcoded *Fusarium* isolates
and produces annotated genome assemblies. Isolates are processed in batches — some batches
contain 10 isolates, others less — and the pipeline is designed to resume cleanly at any stage
for any subset of barcodes.

**Genome size:** ~50–55 Mb (typical for *Fusarium* spp.)  
**Target coverage:** 100×  
**Minimum read length:** 500 bp  
**Basecalling:** Dorado, SUP model recommended

### Pipeline at a glance

```
POD5 files from Sequencer
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
        ├── 3.1 BUSCO (hypocreales / sordariomycetes lineages)
        └── Merqury, CRAQ, and Quast
        │
        ▼
Stage 4 — Genome annotation
        ├── 4.1  Sort and filter assembly (Funannotate sort)
        ├── 4.2  Repeat element detection (EarlGrey)
        ├── 4.3  Soft-mask assembly (Funannotate mask)
        ├── 4.4  BUSCO-based Augustus training
        ├── 4.5  Gene prediction (Funannotate predict)
        └── 4.6  Functional annotation (Funannotate annotate): Interproscan, Eggnog Mapper
        │
        ▼
Stage 5 — Genome-Wide Ananlyses
        ├── 5.1  TelomereSearch.py 
        ├── 5.2  AntiSMASH
        ├── 5.3  CAZymes analysis (Funannotate XXX))
        ├── 5.4  BigScape
        ├── 5.5  Proteins
        ├── 5.6  Effectorome
            ├── 5.6a  Signal6 (Web or local)
            └── 5.6b  Effector3.0
        └── 4.8 C
```

---

## 2. Repository layout

```
Sequencing_WI_Fusarium_Genomes/
├── README.md               ← This file — how the pipeline works
├── BATCHES.md              ← Isolate-level status tracker across all batches
├── PROGRESS.md             ← Session-by-session run log
├── CHANGELOG.md            ← Pipeline and parameter version history
│
├── config/
│   ├── params.env          ← Tool parameters (edit per batch as needed)
│   ├── slurm_profiles.env  ← SLURM resource presets for Ceres/Atlas
│   └── README_config.md    ← Notes on what each parameter controls
│
├── scripts/
│   ├── 01_concat.sh
│   ├── 02_seqkit_dedup.sh
│   ├── 03_porechop.sh
│   ├── 04_nanofilt.sh
│   ├── 05_nanoplot.sh
│   ├── 06_flye_assemble.sh
│   ├── 07_busco_eval.sh
│   └── 08_funannotate.sh
│
├── batches/
│   ├── batch_2025-02/
│   │   ├── barlist.txt     ← Barcodes in this batch
│   │   └── sample_sheet.csv
│   ├── batch_2025-06/
│   │   ├── barlist.txt
│   │   └── sample_sheet.csv
│   └── [batch_YYYY-MM]/
│
├── Atlas Scripts in sequencing pipeline/   ← Legacy — see CHANGELOG.md
│
└── logs/                   ← Auto-populated by sbatch (gitignored)
```

> **Data never lives in this repo.** All `.fastq`, `.fasta`, and assembly files stay on
> Ceres/Atlas under `/90daydata/` or `/project/`. Only manifests and scripts are committed.

---

## 3. Prerequisites

### Environment setup (Ceres)

```bash
# Create the conda environment (one-time setup)
module load miniconda
conda create --prefix /project/silage_microbiome/max.chi/seqenv
conda activate /project/silage_microbiome/max.chi/seqenv
conda install -c bioconda seqkit NanoFilt NanoPlot
```

### Module load reference

Load order matters — see [Known issues](#11-known-issues-and-workarounds) for the
Porechop/miniconda conflict before loading anything.

| Tool | Load command | Used in stage |
|------|-------------|---------------|
| seqkit, NanoFilt, NanoPlot | `module load miniconda` → `source activate seqenv` | 1 |
| Porechop | `module unload miniconda` → `module load porechop` | 1 |
| Flye | `module load flye` | 2 |
| minimap2 + samtools | `module load minimap2 samtools` | 2 (wtdbg2 polish) |
| BUSCO | `module load miniconda` → `source activate seqenv` | 3 |
| EarlGrey | Apptainer image: `earlgrey_dfam3.7_latest.sif` | 4 |
| Funannotate | `module load funannotate augustus blast+ hmmer3` | 4 |

### Required databases and paths

Set these once in `config/params.env` — do not hardcode them in scripts:

| Variable | What it points to |
|----------|------------------|
| `FUNANNOTATE_DB` | Path to Funannotate database |
| `AUGUSTUS_CONFIG_PATH` | Path to writable Augustus config directory |
| `BUSCO_LINEAGE_HYPOCREALES` | Path to hypocreales BUSCO lineage dataset |
| `BUSCO_LINEAGE_SORDARIO` | Path to sordariomycetes BUSCO lineage dataset |
| `EARLGREY_SIF` | Path to EarlGrey Apptainer `.sif` image |

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
srun -A account_name -N 1 -n 40 -p ceres -t 1-0 --pty bash

# 2. Load environment
module load miniconda
source activate seqenv

# 3. Set your working data directory
export WORKDIR=/90daydata/silage_microbiome/[your_batch_path]
cd $WORKDIR

# 4. Confirm your barlist.txt is present and clean
cat batches/batch_YYYY-MM/barlist.txt
# Expected: one barcode name per line, no extension, no blank lines, Unix line endings

# 5. Test on a single barcode before submitting the full batch
TEST=1 bash scripts/04_nanofilt.sh

# 6. Submit full batch
bash scripts/04_nanofilt.sh

# 7. Monitor jobs
squeue -all --me
```

---

## 5. Pipeline stages

### Stage 1 — Data preprocessing

#### 1.1 Concatenate barcode files

Merges all `.fastq.gz` files within each barcode directory into one file per barcode.

```bash
sbatch -N 1 -n 4 --mem=300000 -p short -q msn -t 1-0 \
  --wrap='cat *.fastq.gz > barcodeXX.fastq.gz'
```

> Repeat per barcode, or use `scripts/01_concat.sh` with a barlist.

#### 1.2 Deduplication

```bash
bash scripts/02_seqkit_dedup.sh
# Equivalent sbatch:
sbatch -N 1 -n 70 --mem=900000 -p short-mem -q msn-mem \
  --wrap='while read in; do seqkit rmdup ${in}.fastq.gz -n \
  -o ${in}_D.fastq -D ${in}_derep_list.txt; done < barlist.txt'
```

**Output:** `barcodeXX_D.fastq`, `barcodeXX_derep_list.txt`

#### 1.3 Adapter trimming (Porechop)

> ⚠️ Unload miniconda before loading Porechop. See [Known issues](#11-known-issues-and-workarounds).

```bash
module unload miniconda
module load porechop
bash scripts/03_porechop.sh
# Equivalent sbatch:
sbatch -N 1 -n 70 --mem=900000 -p short-mem -q msn-mem \
  --wrap='while read in; do porechop-runner.py -i ${in}.fastq.gz \
  -o PC_${in}.fastq -t 70; done < barlist.txt'
```

**Output:** `PC_barcodeXX.fastq`

#### 1.4 Length filtering (NanoFilt)

Removes reads below `MIN_LEN` (default 500 bp, set in `config/params.env`).

```bash
module unload porechop
module load miniconda && source activate seqenv
bash scripts/04_nanofilt.sh
```

**Output:** `barcodeXX.fastq` (filtered)

#### 1.5 Quality assessment (NanoPlot)

```bash
bash scripts/05_nanoplot.sh
# Equivalent sbatch:
sbatch -N 1 -n 70 --mem=900000 -p short-mem -q msn-mem \
  --wrap='while read in; do NanoPlot --fastq ${in}.fastq \
  --raw --tsv_stats --N50 -o ${in}; done < barlist.txt'
```

**Output:** Per-barcode directory containing `NanoPlot-report.html` and TSV stats

---

### Stage 2 — Genome assembly

#### Option A: Flye (recommended)

Flye is preferred for *Fusarium* ONT data. Runtime ~58 min per isolate at 40 threads.

```bash
module load flye
bash scripts/06_flye_assemble.sh
# Equivalent sbatch:
sbatch -N 1 -n 40 --mem=300000 -p short -q msn -t 1-0 \
  --wrap='flye --nano-corr barcodeXX.fastq --threads 40 \
  --genome-size 50m --asm-coverage 100 --iterations 1 \
  --out-dir barcodeXX_flye_assembly'
```

#### Option B: wtdbg2

```bash
# Step 1 — Assemble
./wtdbg2 -x ont -g 55m -i barcodeXX.fastq -t 16 -fo prefix

# Step 2 — Consensus
sbatch -N 1 -n 6 --mem=70000 -p short -q msn -t 30 \
  --wrap='wtpoa-cns -t 16 -i prefix.ctg.lay.gz -fo prefix.ctg.fa'

# Step 3 — Polish with minimap2 + samtools
module load minimap2 samtools
minimap2 -t 16 -x map-pb -a prefix.ctg.fa barcodeXX.fastq | \
  samtools view -Sb - > prefix.ctg.map.bam
samtools sort prefix.ctg.map.bam -o prefix.ctg.map.srt.bam
samtools view prefix.ctg.map.srt.bam | \
  wtpoa-cns -t 16 -d prefix.ctg.fa -i - -fo prefix.ctg.2nd.fa
```

**Installation (one-time):**

```bash
git clone https://github.com/ruanjue/wtdbg2
cd wtdbg2 && make
cp wtdbg2 wtpoa-cns /path/to/conda/env/bin/
```

---

### Stage 3 — Assembly evaluation

```bash
bash scripts/07_busco_eval.sh
# Equivalent sbatch:
sbatch -N 1 -n 70 --mem=900000 -p short-mem -q msn-mem \
  --wrap='busco -i polishedXX_assembly.fasta \
  -o assembly_output_eval/busco -l hypocreales \
  --mode genome -c 70'
```

**Output:** `short_summary.*.busco.txt`

---

### Stage 4 — Genome annotation

#### 4.1 Sort and filter assembly

```bash
funannotate sort -i polishedXX_assembly.fasta --minlen 1000 \
  -o barXX_assem_sort.fa
```

#### 4.2 Repeat element detection (EarlGrey)

```bash
apptainer run $EARLGREY_SIF
earlGrey -g barXX_assem_sort.fa -s fcXX -t 20 -o TE_EarlGrey/
```

#### 4.3 Soft-mask assembly

```bash
export AUGUSTUS_CONFIG_PATH   # set in config/params.env
funannotate mask -i barXX_assem_sort.fa -m repeatmodeler \
  -l fcXX-families.fa -o SM_Mask/assem_XX_masked.fa
```

#### 4.4 BUSCO-based Augustus training

Runtime ~varies. Uses sordariomycetes lineage.

```bash
sbatch -N 1 -n 40 --mem=50000 -p short-mem -q msn-mem -t 2-0 \
  --wrap='./funannotate-BUSCO2.py \
  --local_augustus $AUGUSTUS_CONFIG_PATH \
  --long --tarzip \
  -i SM_Mask/assem_XX_masked.fa \
  -o barXXFus_prelim \
  -sp fusarium --tmp scratch \
  -l sordariomycetes_odb10 -m genome -c 40'
```

#### 4.5 Gene prediction (Funannotate predict)

Runtime ~7 hours per isolate.

```bash
sbatch -N 1 -n 20 --mem=50000 -p short -q msn -t 2-0 \
  --wrap="funannotate predict \
  -i SM_Mask/assem_XX_masked.fa \
  -s BarXXFusCer \
  --protein_evidence sordariomycetes_odb10/refseq_db.faa \
  -o FunAnotXXSor --cpu 20 \
  --busco_seed_species BUSCO_barXXFcer_prelim_XXXXXXXXX \
  --busco_db sordariomycetes \
  --optimize_augustus"
```

---

## 6. Configuration

All tunable values live in `config/params.env`. Edit this file — not the scripts —
when adjusting parameters between batches.

```bash
# config/params.env (key variables)

# ── Read filtering ───────────────────────────────────────
export MIN_LEN=500              # Minimum read length bp (NanoFilt -l)

# ── Assembly ─────────────────────────────────────────────
export GENOME_SIZE="50m"        # Expected genome size for Flye
export COVERAGE=100             # Target assembly coverage

# ── SLURM resources ──────────────────────────────────────
export THREADS=70
export MEM_HIGH=900000          # MB — dedup, porechop, BUSCO
export MEM_MED=300000           # MB — concat, Flye
export MEM_LOW=50000            # MB — annotation steps
export PARTITION_MEM="short-mem"
export QOS_MEM="msn-mem"
export PARTITION_STD="short"
export QOS_STD="msn"

# ── Paths (set once per system) ──────────────────────────
export FUNANNOTATE_DB=/project/silage_microbiome/max.chi/funannotate_db
export AUGUSTUS_CONFIG_PATH=/project/silage_microbiome/max.chi/augustus_config
export EARLGREY_SIF=/project/silage_microbiome/max.chi/earlgrey_dfam3.7_latest.sif
```

After editing, reload in your current session:

```bash
source config/params.env
```

---

## 7. Running on a new batch

```bash
# 1. Create a batch folder named by year-month
mkdir -p batches/batch_YYYY-MM

# 2. Add barlist.txt (one barcode name per line, no extension)
nano batches/batch_YYYY-MM/barlist.txt

# 3. Add sample_sheet.csv (barcode, isolate ID, collection info)
nano batches/batch_YYYY-MM/sample_sheet.csv

# 4. Copy barlist to your Ceres working directory
cp batches/batch_YYYY-MM/barlist.txt /90daydata/[path]/sequence_cleanup/

# 5. Update BATCHES.md — add new isolates with status "not started"

# 6. Commit
git add batches/batch_YYYY-MM/ BATCHES.md
git commit -m "batch: add YYYY-MM — N isolates (barcodeXX–YY)"

# 7. Run pipeline stages in order, updating PROGRESS.md each session
```

---

## 8. Testing a single barcode

All scripts support `TEST=1` mode, which processes only the first barcode in `barlist.txt`.
Always test before submitting a full batch.

```bash
TEST=1 bash scripts/04_nanofilt.sh
# Inspect output, then:
bash scripts/04_nanofilt.sh
```

---

## 9. Output files

### Stage 1 — Preprocessing

| File | Description |
|------|-------------|
| `*_D.fastq` | Deduplicated reads |
| `*_derep_list.txt` | Log of removed duplicates |
| `PC_*.fastq` | Adapter-trimmed reads |
| `*.fastq` | Length-filtered reads |
| `*/NanoPlot-report.html` | Per-barcode QC report |
| `*/NanoStats.tsv` | Per-barcode QC stats (TSV) |

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

| File | Description |
|------|-------------|
| `*_assem_sort.fa` | Sorted, minimum-length-filtered assembly |
| `*-families.fa` | Repeat library (EarlGrey) |
| `*_masked.fa` | Soft-masked assembly |
| `*.gff3` | Gene predictions |
| `*.gbk` | GenBank format annotations |
| `*.tbl` | NCBI-format annotation table |

---

## 10. SLURM resource reference

| Stage | Script | Nodes | CPUs | Memory | Time | Partition |
|-------|--------|-------|------|--------|------|-----------|
| Deduplication | 02 | 1 | 70 | 900 GB | 1 day | short-mem |
| Porechop | 03 | 1 | 70 | 900 GB | 1 day | short-mem |
| NanoFilt/NanoPlot | 04–05 | 1 | 70 | 900 GB | 1 day | short-mem |
| Flye assembly | 06 | 1 | 40 | 300 GB | 1 day | short |
| BUSCO evaluation | 07 | 1 | 70 | 900 GB | 1 day | short-mem |
| Gene prediction | 08 | 1 | 20 | 50 GB | 2 days | short |

**Interactive session (always start here):**

```bash
srun -N 1 -n 2 --mem=100000 -p short -q msn -t 1-0 --pty bash
```

**Job monitoring:**

```bash
squeue --me              # your running/queued jobs
scancel JOBID            # cancel a job
cat logs/step-JOBID.out  # view stdout
cat logs/step-JOBID.err  # view stderr
```

---

## 11. Known issues and workarounds

### Porechop vs. miniconda module conflict

Porechop uses a system Python that conflicts with the miniconda-managed environment.
Always follow this exact load order:

```bash
# Before Porechop:
module unload miniconda
module load porechop

# After Porechop, to return to conda tools:
module unload porechop
module load miniconda
source activate seqenv
```

Skipping this causes cryptic Python import errors.

### Augustus write permissions

Augustus requires a writable config directory. Set this up once:

```bash
mkdir -p /project/silage_microbiome/max.chi/augustus_config
export AUGUSTUS_CONFIG_PATH=/project/silage_microbiome/max.chi/augustus_config
chmod -R 770 $AUGUSTUS_CONFIG_PATH
```

### barlist.txt format

The barlist must contain bare barcode names — no file extensions, no trailing whitespace,
Unix line endings. Validate with:

```bash
cat -A barlist.txt       # each line should end with $ not ^M$
dos2unix barlist.txt     # fix Windows line endings if needed
wc -l barlist.txt        # confirm expected number of barcodes
```

### /90daydata purge policy

Files on `/90daydata/` are auto-deleted after 90 days of no access. Before a batch goes
idle, copy final outputs to `/project/` and log the destination in `BATCHES.md`.

---

## 12. Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `conda: command not found` | miniconda not loaded | `module load miniconda` |
| `porechop: ImportError` | miniconda still loaded | `module unload miniconda` first |
| Job disappears from queue immediately | Script syntax error | Check `logs/[step]-JOBID.err` |
| Empty output `.fastq` | Wrong barlist path or CWD | Check `BARLIST` in `params.env` |
| `srun` hangs at prompt | Cluster at capacity | Add `-t 4:00:00` or try `short` partition |
| Augustus permission denied | Config dir not writable | `chmod -R 770 $AUGUSTUS_CONFIG_PATH` |
| Funannotate predict fails | `FUNANNOTATE_DB` not set | `source config/params.env` first |
| Batch processing fails mid-loop | Memory or time limit hit | Check `.err` log; rerun failed barcodes individually |

---

## 13. Citation

If you use this pipeline, please cite the relevant tools:

- **Flye:** Kolmogorov et al. (2019) *Nature Biotechnology*
- **BUSCO:** Manni et al. (2021) *Molecular Biology and Evolution*
- **Funannotate:** Palmer & Stajich — https://github.com/nextgenusfs/funannotate
- **EarlGrey:** Baril & Imrie (2023)
- **NanoPlot / NanoFilt:** De Coster et al. (2018) *Bioinformatics*
- **Porechop:** Wick et al. — https://github.com/rrwick/Porechop
- **seqkit:** Shen et al. (2016) *PLOS ONE*
- **wtdbg2:** Ruan & Li (2020) *Nature Methods*

---

*For questions, open an issue on GitHub or contact Maxwell Chibuogwu.*
