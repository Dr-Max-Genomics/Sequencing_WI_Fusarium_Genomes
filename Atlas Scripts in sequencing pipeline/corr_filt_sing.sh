#!/bin/bash

#SBATCH --job-name="Dor_Correction"   	   #name of this job
#SBATCH -A silage_microbiome		   #name of account
#SBATCH -p gpu-a100	                   #name of the partition (queue) you are submitting to
#SBATCH --gres=gpu:a100:1
#SBATCH --qos=normal		 	   #Quality of service for the job
#SBATCH -n 72                   	   #number of logical cores
#SBATCH -t 50:00:00        		   #time allocated for this job hours:mins:seconds
#SBATCH --mail-user=maxwell.chibuogwu@usda.gov   #enter your email address to receive emails
#SBATCH --mail-type=BEGIN,END,FAIL #will receive an email when job starts, ends or fails
#SBATCH -o "log/stdout.%j.%N"          # standard output, %j adds job number to output file name and %N adds the node name
#SBATCH -e "log/stderr.%j.%N"          #optional, prints standard error





# [EDIT THE CODE BELOW] Load modules, insert code, and run programs

#module load <module_name>         # optional, uncomment the line and load
date
module purge

module load dorado

dorado correct barcode49.fastq > correct_sing_barcode49.fastq

module purge
date
