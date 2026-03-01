#! /bin/bash

#SBATCH --job-name=paired_qualitat				# Job name
#SBATCH --output=paired_qualitat.%j.out		# Name of stdout output file (%j expands to %jobId)
#SBATCH --error=paired_qualitat.%j.err		# Name of stdout output file (%j expands to %jobId)
#SBATCH --cpus-per-task=4			# Specifies that the job requires 6 CPUs
#SBATCH --mem=32G				# Specifies that the job requires 48 gigabytes of memory.

module load miniconda3
source ~/.bashrc
conda activate shotgun1

INPUT_DIR="/cabina/digdb/MBio/IBD_Biologics/trimmomatic_seq"
OUTPUT_DIR="/cabina/digdb/MBio/IBD_Biologics/quality_paired_seq"
mkdir -p "$OUTPUT_DIR"

fastqc -t 4 "$INPUT_DIR"/*_R1_paired.fastq.gz "$INPUT_DIR"/*_R2_paired.fastq.gz -o "$OUTPUT_DIR"


module purge
echo "All tasks completed"
