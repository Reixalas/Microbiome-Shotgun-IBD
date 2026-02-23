#!/bin/bash

#SBATCH --job-name=megahit_R
#SBATCH --output=megahit_R.%j.out
#SBATCH --error=megahit_R.%j.err
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G

module load miniconda3
source ~/.bashrc
conda activate megahit

INPUT_DIR="/home/41701728z/indexos"
OUTPUT_ROOT="/home/41701728z/assemblies"

mkdir -p "$OUTPUT_ROOT"

for R1 in "$INPUT_DIR"/*_nonhuman_R1.fastq.gz; do
    BASE=$(basename "${R1}" _nonhuman_R1.fastq.gz)
    R2="$INPUT_DIR"/"$BASE"_nonhuman_R2.fastq.gz
    
    megahit \
    -1 "$R1" \
    -2 "$R2" \
    -t 4 \
    -o "$OUTPUT_ROOT/megahit_$BASE" 
done
