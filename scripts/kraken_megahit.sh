#!/bin/bash

#SBATCH --job-name=kraken_bowtie
#SBATCH --output=kraken_bowtie.%j.out
#SBATCH --error=kraken_bowtie.%j.err
#SBATCH --cpus-per-task=16            # Pugem a 8 per anar més ràpid
#SBATCH --mem=128G                    # Mantenim els 128G per seguretat amb la DB

module load miniconda3
source ~/.bashrc
conda activate shotgun1

BASE_DADES="/cabina/comu/mbiodb/shotgun1/kraken_db1"
INPUT_DIR="/home/41701728z/indexos"
OUTPUT_DIR="/home/41701728z/kraken_bowtie"

mkdir -p "$OUTPUT_DIR"


for R1 in "$INPUT_DIR"/*_nonhuman_R1.fastq.gz; do
    BASE=$(basename "${R1}" _nonhuman_R1.fastq.gz)
    R2="$INPUT_DIR/${BASE}_nonhuman_R2.fastq.gz"
    
    echo "Processing sample: $BASE"

    kraken2 --db "$BASE_DADES" \
        --paired \
        --gzip-compressed \
        --threads 32 \
        --report "$OUTPUT_DIR/${BASE}_report.txt" \
        --output "$OUTPUT_DIR/${BASE}_output.txt" \
        "$R1" "$R2"
done

module purge
echo "All tasks completed"
