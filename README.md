# Sequencing_WI_Fusarium_Genomes
This repository is for all the scripts used in the genomics pipeline for Fusarium species isolated in Wisconsin

# The Project
Contains a series of steps from NanoPore sequencing, basecalling, to genomic analyses of Fusarium DNA.

# Project Utility 
This project is useful because it serves to presents several pipelines for repeatable genomic analyses.

# How to Use 
Users can get started with the project by...

# Maintenance
The project is maintained by Maxwell Chibuogwu (Dr. Max), postdoctoral fellow at USDA-ARS DFRC, Madison, WI and contribution to the project by colleagues is wellcome.

# Fusarium Whole Genome Sequencing Pipeline

A comprehensive bioinformatics pipeline for whole genome sequencing and annotation of *Fusarium* species using Oxford Nanopore long-read sequencing data on SciNet's Ceres and Atlas HPC clusters.

**Author:** Maxwell Chibuogwu  
**Date:** 2025-02-14  
**Project:** Silage Microbiome Study

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Pipeline Workflow](#pipeline-workflow)
4. [Installation](#installation)
5. [Usage](#usage)
6. [Output Files](#output-files)
7. [Troubleshooting](#troubleshooting)
8. [Citation](#citation)

---

## Overview

This pipeline processes Oxford Nanopore sequencing data from barcoded *Fusarium* isolates through quality control, genome assembly, evaluation, and functional annotation. The workflow is optimized for execution on USDA's Ceres and Atlas HPC systems.

### Key Features

- **Quality Control**: Adapter trimming, deduplication, and length filtering
- **Genome Assembly**: Multiple assembler options (Flye, wtdbg2)
- **Assembly Evaluation**: BUSCO completeness assessment
- **Genome Annotation**: Repeat masking and gene prediction using Funannotate

---

## Prerequisites

### Required Modules (Ceres)

```bash
module load miniconda
module load porechop
module load flye
module load minimap2
module load samtools
module load funannotate
module load augustus
module load blast+
module load hmmer3
```

### Required Conda Environment

```bash
conda create --prefix /project/silage_microbiome/max.chi/seqenv
conda activate /project/silage_microbiome/max.chi/seqenv
conda install -c bioconda seqkit NanoFilt NanoPlot
```

### Required Apptainer Images

- EarlGrey (TE annotation): `earlgrey_dfam3.7_latest.sif`

### Databases

- Funannotate database
- BUSCO databases (hypocreales, sordariomycetes)
- Augustus config files

---

## Pipeline Workflow

### 1. Data Preprocessing

#### 1.1 Concatenate Barcode Files

```bash
sbatch -N 1 -n 4 --mem=300000 -p short -q msn -t 1-0 \
  --wrap='cat *.fastq.gz > barcodeX.fastq.gz'
```

#### 1.2 Deduplication

```bash
sbatch -N 1 -n 70 --mem=900000 -p short-mem -q msn-mem \
  --wrap='while read in; do seqkit rmdup ${in}.fastq.gz -n -o ${in}_D.fastq \
  -D ${in}_derep_list.txt; done < barlist.txt'
```

#### 1.3 Adapter Trimming

```bash
module load porechop
sbatch -N 1 -n 70 --mem=900000 -p short-mem -q msn-mem \
  --wrap='while read in; do porechop-runner.py -i ${in}.fastq.gz \
  -o PC_${in}.fastq -t 70; done < barlist.txt'
```

#### 1.4 Length Filtering

```bash
while read in; do NanoFilt -l 500 PC_${in}.fastq > ${in}.fastq; \
  done < barlist.txt
```

#### 1.5 Quality Assessment

```bash
sbatch -N 1 -n 70 --mem=900000 -p short-mem -q msn-mem \
  --wrap='while read in; do NanoPlot --fastq ${in}.fastq --raw \
  --tsv_stats --N50 -o ${in}; done < barlist.txt'
```

### 2. Genome Assembly

#### Option A: Flye Assembler (Recommended)

```bash
module load flye
sbatch -N 1 -n 40 --mem=300000 -p short -q msn -t 1-0 \
  --wrap='flye --nano-corr barcode56.fastq --threads 40 \
  --genome-size 50m --asm-coverage 100 --iterations 1 \
  --out-dir barcode56_flye_assembly'
```

**Runtime:** ~58 minutes per isolate

#### Option B: wtdbg2 Assembler

```bash
# Assembly
./wtdbg2 -x ont -g 55m -i barcode56.fastq -t16 -fo prefix

# Derive consensus
sbatch -N 1 -n 6 --mem=70000 -p short -q msn -t 30 \
  --wrap='wtpoa-cns -t16 -i prefix.ctg.lay.gz -fo prefix.ctg.fa'

# Polish with minimap2 and samtools
minimap2 -t 16 -x map-pb -a prefix.ctg.fa barcode56.fastq | \
  samtools view -Sb - > prefix.ctg.map.bam
samtools sort prefix.ctg.map.bam -o prefix.ctg.map.srt.bam
samtools view prefix.ctg.map.srt.bam | wtpoa-cns -t 16 \
  -d prefix.ctg.fa -i - -fo prefix.ctg.2nd.fa
```

### 3. Assembly Evaluation

```bash
sbatch -N 1 -n 70 --mem=900000 -p short-mem -q msn-mem \
  --wrap='busco -i polished56_assembly.fasta \
  -o assembly_output_eval/busco -l hypocreales --mode genome -c 70'
```

### 4. Genome Annotation

#### 4.1 Sort Assembly

```bash
funannotate sort -i polished56_assembly.fasta --minlen 1000 \
  -o bar56_assem_sort.fa
```

#### 4.2 Repeat Element Detection (EarlGrey)

```bash
apptainer run earlgrey_dfam3.7_latest.sif
earlGrey -g bar56_assem_sort.fa -s fc56 -t 20 -o TE_EarlGrey/
```

#### 4.3 Soft Mask Assembly

```bash
export AUGUSTUS_CONFIG_PATH=/path/to/augustus/config
funannotate mask -i bar56_assem_sort.fa -m repeatmodeler \
  -l fc56-families.fa -o SM_Mask/assem_56_masked.fa
```

#### 4.4 Preliminary BUSCO Training

```bash
export AUGUSTUS_CONFIG_PATH=/path/to/augustus/config
sbatch -N 1 -n 40 --mem=50000 -p short-mem -q msn-mem -t 2-0 \
  --wrap='./funannotate-BUSCO2.py --local_augustus $AUGUSTUS_CONFIG_PATH \
  --long --tarzip -i SM_Mask/assem_56_masked.fa -o bar56Fus_prelim \
  -sp fusarium --tmp scratch -l sordariomycetes_odb10 -m genome -c 40'
```

#### 4.5 Gene Prediction

```bash
export FUNANNOTATE_DB=/path/to/funannotate_db
sbatch -N 1 -n 20 --mem=50000 -p short -q msn -t 2-0 \
  --wrap="funannotate predict -i SM_Mask/assem_56_masked.fa \
  -s Bar56FusCer --protein_evidence sordariomycetes_odb10/refseq_db.faa \
  -o FunAnot56Sor --cpu 20 \
  --busco_seed_species BUSCO_bar56Fcer_prelim_1221400862 \
  --busco_db sordariomycetes --optimize_augustus"
```

**Runtime:** ~7 hours per isolate

---

## Installation

### 1. Clone Required Tools

```bash
# wtdbg2 (if using)
git clone https://github.com/ruanjue/wtdbg2
cd wtdbg2 && make
cp wtdbg2 wtpoa-cns /path/to/conda/env/bin/
```

### 2. Set Up Funannotate Database

```bash
funannotate setup -u -w -d /path/to/funannotate_db/
```

### 3. Download BUSCO Databases

```bash
# Download hypocreales and sordariomycetes lineage datasets
busco --download hypocreales
busco --download sordariomycetes
```

### 4. Configure Augustus

```bash
mkdir /path/to/augustus/config
export AUGUSTUS_CONFIG_PATH=/path/to/augustus/config
chmod -R 770 $AUGUSTUS_CONFIG_PATH
```

---

## Usage

### Quick Start

1. **Prepare barcode list file** (`barlist.txt`):
   ```
   barcode49
   barcode50
   barcode51
   ```

2. **Run preprocessing pipeline**:
   ```bash
   bash 01_preprocess.sh barlist.txt
   ```

3. **Assemble genomes**:
   ```bash
   bash 02_assemble.sh barlist.txt
   ```

4. **Annotate genomes**:
   ```bash
   bash 03_annotate.sh barlist.txt
   ```

### Interactive Sessions

For testing or troubleshooting:

```bash
srun -N 1 -n 2 --mem=100000 -p short -q msn -t 1-0 --pty bash
```

### Monitor Jobs

```bash
squeue -u maxwell.chibuogwu  # Check running jobs
scancel JOBID                 # Cancel a job
cat slurm-JOBID.out          # View job output
```

---

## Output Files

### Quality Control
- `*_D.fastq` - Deduplicated reads
- `PC_*.fastq` - Adapter-trimmed reads
- `*.fastq` - Length-filtered reads
- `*/NanoPlot-report.html` - Quality statistics

### Assembly
- `assembly.fasta` - Final genome assembly
- `assembly_info.txt` - Assembly statistics
- `flye.log` - Assembly log

### Evaluation
- `short_summary.*.busco.txt` - BUSCO completeness report

### Annotation
- `*_assem_sort.fa` - Sorted assembly
- `*_masked.fa` - Repeat-masked assembly
- `*-families.fa` - Repeat library
- `*.gff3` - Gene predictions
- `*.gbk` - GenBank format annotations
- `*.tbl` - Annotation table

---

## Troubleshooting

### Common Issues

**Problem:** Batch processing fails  
**Solution:** Process files individually instead of using while loops

**Problem:** Memory errors  
**Solution:** Request more memory with `--mem=` flag or use `-mem` partition

**Problem:** Porechop/miniconda conflicts  
**Solution:** Always `module unload porechop` before loading miniconda

**Problem:** Augustus permissions errors  
**Solution:** Ensure write permissions: `chmod -R 770 $AUGUSTUS_CONFIG_PATH`

### Resource Requirements

| Step | Nodes | CPUs | Memory | Time | Partition |
|------|-------|------|--------|------|-----------|
| Deduplication | 1 | 70 | 900GB | 1 day | short-mem |
| Porechop | 1 | 70 | 900GB | 1 day | short-mem |
| Flye assembly | 1 | 40 | 300GB | 1 day | short |
| BUSCO | 1 | 70 | 900GB | 1 day | short-mem |
| Gene prediction | 1 | 20 | 50GB | 2 days | short |

---

## File Structure

```
project/
├── fastq_pass/              # Raw sequencing data
├── isolate_fastq/           # Processed FASTQ files
│   ├── sequence_cleanup/    # QC outputs
│   ├── genome_assembly/     # Assembly outputs
│   └── 11_FunAnnotate/      # Annotation outputs
├── barlist.txt              # Sample identifier list
└── scripts/                 # Pipeline scripts
```

---

## Notes

- **Genome size:** ~50-55 Mb (typical for *Fusarium* species)
- **Coverage:** Target 100x coverage for optimal assembly
- **Read length cutoff:** 500 bp minimum recommended
- **Basecalling:** Use Dorado with SUP model for best accuracy
- **Storage:** Use `/90daydata/` for temporary files (auto-deleted after 90 days)
- **Permanent storage:** Use `/project/` for final results

---

## Citation

If you use this pipeline, please cite the relevant tools:

- **Flye:** Kolmogorov et al. (2019) Nature Biotechnology
- **BUSCO:** Manni et al. (2021) Molecular Biology and Evolution
- **Funannotate:** Palmer & Stajich (GitHub)
- **EarlGrey:** Baril & Imrie (2023)
- **NanoPlot/NanoFilt:** De Coster et al. (2018) Bioinformatics
- **Porechop:** Wick et al. (GitHub)

---

## Contact

For questions or issues with this pipeline:
- **Author:** Maxwell Chibuogwu
- **Project:** Wisconsin Fusarium Genomes
- **Institution:** USDA-ARS Dairy Forage Research Center (via SciNet)

---

## License

This pipeline is provided as-is for research purposes. Individual tools retain their respective licenses.
