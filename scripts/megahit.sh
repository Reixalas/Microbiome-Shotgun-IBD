#!/bin/bash

#SBATCH --job-name=megahit_R
#SBATCH --output=megahit_R.%j.out
#SBATCH --error=megahit_R.%j.err
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G

module load miniconda3
source ~/.bashrc
conda activate megahit

INPUT_DIR="/cabina/digdb/MBio/IBD_Biologics/bowtie_seq"
OUTPUT_ROOT="/cabina/digdb/MBio/IBD_Biologics/megahit_seq"

mkdir -p "$OUTPUT_ROOT"

for R1 in "$INPUT_DIR"/*_nonhuman_R1.fastq.gz; do
    BASE=$(basename "${R1}" _nonhuman_R1.fastq.gz)
    R2="$INPUT_DIR"/"$BASE"_nonhuman_R2.fastq.gz
    
    megahit \
    -1 "$R1" \
    -2 "$R2" \
    -t 8 \
    -o "$OUTPUT_ROOT/megahit_$BASE" 
done

module purge
echo "All tasks completed"
