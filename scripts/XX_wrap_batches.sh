### BATCH 2: Remove duplicate reads using seqkit rmdup ###
# -n: checks by sequence name to find duplicates.
# -o: specifies the output file for dereplicated sequences.
# -D: specifies the output file for the list of duplicated reads.
sbatch -A silage_microbiome -N 1 -n 4 --mem=300000 -p ceres --wrap='while read in; \
do seqkit rmdup ${in}.fastq -n -o ${in}_D.fastq -D ${in}_derep_list.txt; done < barlist.txt'

### 5. Assembly Evaluation with BUSCO
#BUSCO (Benchmarking Universal Single-Copy Orthologs) assesses the completeness of a genome assembly by checking for the presence of a curated set of expected genes.

sbatch -A silage_microbiome --array=1-9 -N 1 -n 4 --mem=40000 -p ceres -t 1:00:00 \
  --wrap='in=$(sed -n "${SLURM_ARRAY_TASK_ID}p" pol_barlist.txt); busco -i ${in} \
  -o ${in}_busco_eval -l hypocreales --mode genome -c 40 --offline'

### Step 6.1: Create Repeat Library with Earl Grey

#This step identifies transposable elements (TEs) to create a custom repeat library for soft masking. 

sbatch -A silage_microbiome --array=36-45 -N 1 -n 16 --mem=50000 -p ceres -t 5:00:00 --wrap='in=${SLURM_ARRAY_TASK_ID}; \
mkdir -p 11_FunAnnotate/TE_EarlGrey/bar${in}; apptainer run earlgrey_dfam3.7_latest.sif earlGrey \
-g 07_Polished_Genome/cleaned_bar${in}_pol_assembly.fasta -s fus${in} -t 40 -o 11_FunAnnotate/TE_EarlGrey/bar${in}

### Step 6.2: Sort and Mask Assembly

#Prepare the assembly by sorting contig and soft-masking the repeats identified by Earl Grey

#batch sort and mask
sbatch -A silage_microbiome --array=37-45 -N 1 -n 2 --mem=5000 -p ceres -t 20:00 --wrap='in=${SLURM_ARRAY_TASK_ID}; \
  funannotate sort -i 07_Polished_Genome/cleaned_bar${in}_pol_assembly.fasta \
  --minlen 1000 -o 11a_FunAnnotateOut/bar${in}_assem_sort.fa && funannotate mask -i 11a_FunAnnotateOut/bar${in}_assem_sort.fa -m repeatmodeler \
  -l 11_FunAnnotate/TE_EarlGrey/bar${in}/fus${in}_EarlGrey/fus${in}_Database/fus${in}-families.fa -o 11a_FunAnnotateOut/assem_${in}_masked.fa'


### Step 6.3: Predict Genes

#This is the core prediction step. It uses evidence from BUSCO, protein databases, and ab initio predictors like AUGUSTUS. `funannotate` $funannotate$ first trains its predictors on your specific genome.

sbatch -A silage_microbiome -N 1 -n 20 --mem=50000 -p ceres -t 2-0 --wrap="\
funannotate predict \
  -i assem_56_masked.fa \
  -s 'Fusarium sp. Bar56' \
  --protein_evidence ../BD_BuscoDatabase/sordariomycetes_odb10/refseq_db.faa \
  -o FunAnnotate_Bar56 \
  --cpu 20 \
  --busco_db sordariomycetes \
  --optimize_augustus"
