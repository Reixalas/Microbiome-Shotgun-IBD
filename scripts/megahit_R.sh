#!/bin/bash

#SBATCH --job-name=megahit_R
#SBATCH --output=megahit_R.%j.out
#SBATCH --error=megahit_R.%j.err
#SBATCH --ntasks=10
#SBATCH --cpus-per-task=2
#SBATCH --mem=160G						# Specifies that the job requires at least 2 gigabytes of memory.

module load miniconda3
source ~/.bashrc
conda activate megahit


# Set the maximum number of parallel tasks
parallel_tasks=10
task_counter=0


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
    -o "$OUTPUT_ROOT/megahit_$BASE" &   
    
    
    # Increment the task counter
    	    ((task_counter++))
    	
    	    # Check if the maximum number of parallel tasks is reached
    	    if [ $task_counter -eq $parallel_tasks ]; then
    	        # Wait for all currently running tasks to finish before starting new ones
    	        wait
    	        # Reset the task counter
    	        task_counter=0
    fi
    
    
done

module purge
echo "All tasks completed"
