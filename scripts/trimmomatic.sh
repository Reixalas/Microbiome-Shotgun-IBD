#!/bin/bash

#SBATCH --job-name=trimmomatic_R			# Job name
#SBATCH --output=trimmomatic_R.%j.out		# Name of stdout output file (%j expands to %jobId)
#SBATCH --error=trimmomatic_R.%j.err		# Name of stdout output file (%j expands to %jobId)
#SBATCH --cpus-per-task=4			# Specifies that the job requires 6 CPUs
#SBATCH --mem=32G				# Specifies that the job requires 48 gigabytes of memory.

module load miniconda3
source ~/.bashrc
conda activate shotgun1

INPUT_DIR="/opt/ohpc/pub/utils/miniconda3/envs/shotgun1/share/trimmomatic-0.40-0/adapters/NexteraPE-PE.fa"
OUTPUT_DIR="/home/41701728z/trimmo"
INPUT_SEQ="/cabina/digdb/MBio/IBD_Biologics_5samples/Seq"
mkdir -p "$OUTPUT_DIR"
for R1 in "$INPUT_SEQ"/*_1.fastq.gz; do
	BASE=$(basename "${R1}" _1.fastq.gz)
	R2="$INPUT_SEQ"/"$BASE"_2.fastq.gz

	trimmomatic PE -threads 4 \
	"$R1" "$R2" \
	"$OUTPUT_DIR"/"$BASE"_R1_paired.fastq.gz \
	"$OUTPUT_DIR"/"$BASE"_R1_unpaired.fastq.gz \
	"$OUTPUT_DIR"/"$BASE"_R2_paired.fastq.gz \
	"$OUTPUT_DIR"/"$BASE"_R2_unpaired.fastq.gz \
	ILLUMINACLIP:"$INPUT_DIR":2:30:10 \
	LEADING:3 \
	TRAILING:3 \
	SLIDINGWINDOW:4:15 \
	MINLEN:36
done
