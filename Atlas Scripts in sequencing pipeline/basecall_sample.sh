#!/bin/bash

#SBATCH --job-name="Dorado Basecall"   	   #name of this job
#SBATCH -A silage_microbiome		   #name of account
#SBATCH -p gpu-a100	                   #name of the partition (queue) you are submitting to
#SBATCH --gres=gpu:a100:1
#SBATCH --qos=normal		 	   #Quality of service for the job
#SBATCH -n 40                   	   #number of logical cores
#SBATCH -t 03:00:00        		   #time allocated for this job hours:mins:seconds
#SBATCH --mail-user=maxwell.chibuogwu@usda.gov   #enter your email address to receive emails
#SBATCH --mail-type=BEGIN,END,FAIL #will receive an email when job starts, ends or fails
#SBATCH -o "stdout.%j.%N"          # standard output, %j adds job number to output file name and %N adds the node name
#SBATCH -e "stderr.%j.%N"          #optional, prints standard error





# [EDIT THE CODE BELOW] Load modules, insert code, and run programs

#module load <module_name>         # optional, uncomment the line and load
date

module load dorado/0.8.1

dorado basecaller sup PAQ22739_393fbf7f_f71c7bd6_100.pod5 --device cuda:all --min-qscore 15  --emit-fastq > democalls.fastq &> dorado.log

module purge
date
