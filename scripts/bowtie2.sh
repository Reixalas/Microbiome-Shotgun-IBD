#!/bin/bash

#SBATCH --job-name=bowtie2_seq
#SBATCH --output=bowtie2_seq.%j.out
#SBATCH --error=bowtie2_seq.%j.err
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G

export LC_ALL=C

module load miniconda3
source ~/.bashrc
conda activate shotgun1

INPUT_DIR="/cabina/digdb/MBio/IBD_Biologics/trimmomatic_seq"
INDEX_DIR="/cabina/comu/mbiodb/shotgun/human_genome_reference"
RESULTS_DIR="/cabina/digdb/MBio/IBD_Biologics/bowtie_seq"

mkdir -p "$RESULTS_DIR"

for R1 in "$INPUT_DIR"/*_R1_paired.fastq.gz; do
    BASE=$(basename "${R1}" _R1_paired.fastq.gz)
    R2="$INPUT_DIR"/"$BASE"_R2_paired.fastq.gz
    
    echo "Processing sample: $BASE"


    bowtie2 -x "$INDEX_DIR"/GRCh38_index \
    -1 "$R1" \
    -2 "$R2" \
    --very-sensitive \
    -S "$RESULTS_DIR"/"$BASE".sam \
    -p 8
    
    samtools view -uS "$RESULTS_DIR"/"$BASE".sam | samtools sort -o "$RESULTS_DIR"/"$BASE"_sorted.bam -
    
    
    samtools view -b -f 12 -F 256 "$RESULTS_DIR"/"$BASE"_sorted.bam > "$RESULTS_DIR"/"$BASE"_nonhuman.bam 

    
    samtools fastq \
    -1 "$RESULTS_DIR"/"$BASE"_nonhuman_R1.fastq.gz \
    -2 "$RESULTS_DIR"/"$BASE"_nonhuman_R2.fastq.gz \
    -0 /dev/null -s /dev/null -n \
    "$RESULTS_DIR"/"$BASE"_nonhuman.bam 

    
    rm "$RESULTS_DIR"/"$BASE".sam "$RESULTS_DIR"/"$BASE"_sorted.bam "$RESULTS_DIR"/"$BASE"_nonhuman.bam
done

module purge
echo "All tasks completed"
