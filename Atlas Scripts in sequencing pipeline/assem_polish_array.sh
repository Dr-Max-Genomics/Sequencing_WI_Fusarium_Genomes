#!/bin/bash
#SBATCH --job-name="polish_assembly"        # Job name
#SBATCH --account=silage_microbiome         # Account
#SBATCH -p gpu-a100                        #name of the partition (queue) you are submitting to
#SBATCH --gres=gpu:a100:1
#SBATCH --qos=normal                       #Quality of service for the job
#SBATCH -n 16                              #number of logical cores
#SBATCH -t 10:00:00                         # Walltime (hh:mm:ss)
#SBATCH --array=36-45                       # Run for barcodes 36 through 45
#SBATCH -o "polish_log/stdout.%A_%a.%N"            # Stdout (%A = job ID, %a = array index)
#SBATCH -e "polish_log/stderr.%A_%a.%N"            # Stderr
# Load required modules
module purge
module load dorado
module load samtools
date
# Each array task gets its own barcode number
BARCODE=$SLURM_ARRAY_TASK_ID
# Input files (adjust paths if needed)
ASSEMBLY="bar${BARCODE}_assembly.fasta"
READS="bar${BARCODE}_pod5s.bam"
# Output files
ALIGNED="aligned_bar${BARCODE}_calls.bam"
POLISHED="polished${BARCODE}_assembly.fasta"
# Align reads to assembly
dorado aligner "${ASSEMBLY}" "${READS}" | \
    samtools sort --threads 40 > "${ALIGNED}"
# Index BAM
samtools index "${ALIGNED}"
# Detect the correct RG ID for this barcode
RG=$(samtools view -H "${ALIGNED}" | grep "^@RG" | grep "barcode${BARCODE}" | \
     awk '{for(i=1;i<=NF;i++) if($i ~ /^ID:/) print substr($i,4)}')
date
# Polish assembly using the detected RG
dorado polish --RG "${RG}" "${ALIGNED}" "${ASSEMBLY}" > "${POLISHED}"
date
module purge
