#! /bin/bash

#SBATCH --job-name=shotgun				# Job name
#SBATCH --output=shotgun.%j.out		# Name of stdout output file (%j expands to %jobId)
#SBATCH --error=shotgun.%j.err		# Name of stdout output file (%j expands to %jobId)
#SBATCH --cpus-per-task=4			# Specifies that the job requires 6 CPUs
#SBATCH --mem=32G				# Specifies that the job requires 48 gigabytes of memory.

module load miniconda3
source ~/.bashrc
conda activate shotgun1

INPUT_DIR="/cabina/digdb/MBio/IBD_Biologics_5samples/Seq"
OUTPUT_DIR="/home/41701728z/resultatsfastqc"

fastqc "$INPUT_DIR"/*_1.fastq.gz "$INPUT_DIR"/*_2.fastq.gz -o "$OUTPUT_DIR"



# Wait for all background jobs to finish
wait

module purge
echo "All tasks completed"
