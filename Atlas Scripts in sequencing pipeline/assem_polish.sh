#!/bin/bash

#SBATCH --job-name="polish assembly"      #name of this job
#SBATCH --account=silage_microbiome
#SBATCH -p atlas                 #name of the partition (queue) you are submitting to
#SBATCH -N 1                       #number of nodes in this job
#SBATCH -n 40                      #number of logical cores
#SBATCH -t 15:00:00                #time allocated for this job hours:mins:seconds
#SBATCH -o "log/stdout.%j.%N"          # standard output, %j adds job number to output file name and %N adds the node name
#SBATCH -e "log/stderr.%j.%N"          #optional, prints standard error



# [EDIT THE CODE BELOW] Load modules, insert code, and run programs

#module load <module_name>         # optional, uncomment the line and load preinstalled software/libraries/packages

module load dorado
module load samtools

date
dorado aligner barXX_assembled.fasta barXX.bam | samtools sort --threads 40 > aligned_barXX_calls.bam
samtools index aligned_barXX_calls.bam

date
dorado polish --RG f71c7bd693e008b66fe3a0fade1f329de802e763_dna_r10.4.1_e8.2_400bps_sup@v5.0.0_SQK-NBD114-96_barcodeXX aligned_barXX_calls.bam barXX_assembled.fasta > polishedXX_assembly.fasta

module purge

date
