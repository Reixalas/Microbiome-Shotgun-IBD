#!/bin/bash

#SBATCH --job-name=multiqc_paired
#SBATCH --output=multiqc_paired.%j.out
#SBATCH --error=multiqc_paired.%j.err
#SBATCH --cpus-per-task=4        
#SBATCH --mem=32G                 

module load miniconda3
source ~/.bashrc
conda activate shotgun1


FASTQC_DIR="/cabina/digdb/MBio/IBD_Biologics/quality_paired_seq"
TRIM_DIR="/cabina/digdb/MBio/IBD_Biologics/trimmomatic_seq"
OUTPUT_DIR="/cabina/digdb/MBio/IBD_Biologics/multiqc_report"

mkdir -p "$OUTPUT_DIR"


multiqc "$FASTQC_DIR" "$TRIM_DIR" -o "$OUTPUT_DIR" -n report_multiqc_paired
