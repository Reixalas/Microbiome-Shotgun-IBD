#! /bin/bash

#SBATCH --job-name=index				# Job name
#SBATCH --output=index.%j.out		# Name of stdout output file (%j expands to %jobId)
#SBATCH --error=index.%j.err		# Name of stdout output file (%j expands to %jobId)
#SBATCH --cpus-per-task=4			# Specifies that the job requires 6 CPUs
#SBATCH --mem=32G				# Specifies that the job requires 48 gigabytes of memory.

module load miniconda3
source ~/.bashrc
conda activate shotgun1

bowtie2-build GCF_000001405.40_GRCh38.p14_genomic.fna GRCh38_index




# Wait for all background jobs to finish
wait

module purge
echo "All tasks completed"
