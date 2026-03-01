#!/bin/bash

#SBATCH --job-name=kraken_megahit
#SBATCH --output=kraken_megahit.%j.out
#SBATCH --error=kraken_megahit.%j.err
#SBATCH --cpus-per-task=16
#SBATCH --mem=128G

module load miniconda3
source ~/.bashrc
conda activate shotgun1

BASE_DADES="/cabina/comu/mbiodb/shotgun1/kraken_db1"
INPUT_DIR="/home/41701728z/assemblies2"  
OUTPUT_DIR="/home/41701728z/kraken_megahit"

mkdir -p "$OUTPUT_DIR"

for SAMPLE_DIR in "$INPUT_DIR"/megahit_*; do
    BASE=$(basename "$SAMPLE_DIR" | sed 's/megahit_//')
    
    CONTIGS="$SAMPLE_DIR/final.contigs.fa"

    if [ -f "$CONTIGS" ]; then
        echo "----------------------------------------------------"
        echo "Classificant CONTIGS de la mostra: $BASE"
        echo "----------------------------------------------------"

        
        kraken2 --db "$BASE_DADES" \
            --threads 32 \
            --report "$OUTPUT_DIR/${BASE}_contigs_report.txt" \
            --output "$OUTPUT_DIR/${BASE}_contigs_output.txt" \
            "$CONTIGS"
    else
        echo "Atenció: No s'ha trobat el fitxer de contigs a $SAMPLE_DIR"
    fi
done

module purge
echo "Anàlisi taxonòmica de contigs finalitzada."
