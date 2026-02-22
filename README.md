# Shotgun Metagenomics Analysis of IBD Samples

This repository contains the bioinformatics analysis pipeline for processing **114 shotgun metagenomics samples** from the study by **Lee et al. (2021)**, published in *Cell Host & Microbe*. 

The primary objective of the analysis is the study of the gut microbiome in patients with Inflammatory Bowel Disease (IBD). Due to the high data load, an optimized processing strategy has been implemented in **batches of 5 samples**.



---

## Data Availability

The raw sequencing data used in this project are deposited in the **NCBI Sequence Read Archive (SRA)** database. They can be consulted and downloaded using the BioProject identifier:

* **BioProject ID:** [PRJNA685168](https://www.ncbi.nlm.nih.gov/bioproject/?term=PRJNA685168)

---

## Computing Environment Setup

Before executing any stage of the pipeline, it is essential to ensure that the software is correctly activated and configured to work on the cluster. To do so, the following protocol is followed:

* **`module load miniconda3`**: Enables the Conda package manager on the system.
* **`source ~/.bashrc`**: Updates and refreshes the terminal configuration.
* **`conda activate shotgun1`** (or `megahit` depending on the stage): Activates the virtual environment where the specific tools reside (MEGAHIT, Bowtie2, Samtools, etc.).

---

## Stage 1: Quality Control (FastQC)

Before performing any biological inference, it is indispensable to validate the **technical integrity** and reliability of the raw sequencing data.
The script `scripts/shotgunR.sh` has been used to execute the **FastQC** tool in an automated manner. This process analyzes the read files (`.fastq.gz`) and generates diagnostic reports based on four key metrics:

---

#### 1. Per Base Sequence Quality
This graph is the first indicator of technical reliability. It uses boxplots to represent the quality at each position of the read.
* **Interpretation:** The vertical axis represents the Phred Score (Q), a logarithmic scale that indicates the probability of error in identifying each nucleotide. The goal is for practically the entire read to remain within the green zone. If the "boxes" or the mean lines drop into the yellow zone (warning) or red zone (poor quality), the probability that the assigned letters are incorrect increases exponentially. Sequencing machines typically lose quality as they progress toward the end of the read. If this graph shows final degradation, we will use this information to define the clipping point in the trimming stage.



#### 2. Per Sequence GC Content 
Measures the proportion of Guanine and Cytosine, acting as a "genomic fingerprint" of the microbial community.
* **Interpretation:** This module measures the proportion of Guanine and Cytosine in each read and offers an overall view of the genomic composition of the sample. In a complex gut microbiome sample, the graph should show a smooth distribution approximating a Gaussian curve. This is because we are sequencing hundreds of different bacterial species, each with its own GC percentage; the overlapping of all these genomes creates a normalized curve.

#### 3. Per Base Sequence Content
Examines the proportion of the four bases (A, T, C, G) along the length of the read.
* **Interpretation:** Under optimal conditions, the graph should show parallel and stable lines. It is normal to observe a "zigzag" pattern in the first 10-12 bases due to the *random primers* from Illumina. If the lines do not stabilize beyond base 15, it may be a sign of massive adapter presence or low genetic diversity.

#### 4. Adapter Content
Detects synthetic DNA fragments (adapters) used during library preparation in the lab.
* **Interpretation:** Any ascending curve in this module indicates that we must perform filtering with Trimmomatic. The presence of these elements usually occurs when the DNA fragment is shorter than the number of sequencing cycles, causing the machine to read part of the artificial material. It is crucial to remove them completely; even a minimal presence could confuse the MEGAHIT assembler, leading it to join artificial sequences and create "chimeric" or non-existent genomes that would invalidate the results.

---

## Stage 2: Filtering (Trimmomatic)

Once the initial quality has been evaluated with **FastQC**, the second phase of the pipeline focuses on pre-processing. For this task, **Trimmomatic v0.39** has been used, a tool specialized in removing sequencing artifacts and cleaning low-reliability bases. The goal is to avoid introducing errors during *de novo* assembly in later stages.

### Script
The efficiency of the `scripts/trimmo_ruben.sh` script lies in the implementation of a **`for` loop**, which allows for the iterative and automated processing of the 5 samples in the project. The script automatically identifies each pair of files (R1 and R2) and executes Trimmomatic in **PE (Paired-End)** mode. This mode evaluates both reads simultaneously to make coordinated decisions regarding the integrity of the fragment.

A critical point at this stage is the correct selection of the adapter sequence. For this pipeline, the specific path within the working environment has been verified to use the **Nextera** adapter file.

* **Adapter Path:** `/opt/ohpc/pub/utils/miniconda3/envs/shotgun1/share/trimmomatic-0.40-0/adapters/NexteraPE-PE.fa`

### Filtering Parameters
The following modules have been defined to ensure data purity before assembly:

| Parameter | Technical Description |
| :--- | :--- |
| **ILLUMINACLIP:NexteraPE-PE.fa:2:30:10** | Nextera adapter removal. A threshold of **2** mismatches and scores of **30** (palindrome) and **10** (simple) are used to avoid false positives. |
| **LEADING:3** / **TRAILING:3** | Trims bases from the ends (start and finish) if their quality is lower than a **Phred score of 3**. |
| **SLIDINGWINDOW:4:15** | Dynamic quality filter. It analyzes the read in 4-base windows and trims it if the average quality of the segment falls below **15**. |
| **MINLEN:36** | Establishes that any read that, after curation, has a length shorter than **36 bases** is discarded to avoid ambiguities during assembly. |

### Results
As a result of this processing, the program generates four data streams for each sample.

* **Paired (R1/R2):** Both members have passed quality controls. These will be the data we use.
* **Unpaired (R1/R2):** Only one member of the pair has passed the filters. They are discarded.

---

## Stage 3: Host DNA Removal (Bowtie2)

Although the goal of the study is the gut microbiome, fecal samples contain a variable fraction of DNA coming from the patient's cells (host). To analyze the microbial content exclusively, these human reads must be filtered out.

### 3.1. Reference Genome Indexing
Before performing the filtering, it is essential to "prepare" the human genome so the computer can process it efficiently. The original genome file is a massive list of billions of characters that does not allow for efficient direct searching. If we had to search each read within the plain text file of the human genome, the process would take weeks and require an impossible amount of RAM.

The `index.sh` script executes the `bowtie2-build` command, which compresses the genome and organizes it into an optimized data structure:

* **Input:** `GCF_000001405.40_GRCh38.p14_genomic.fna`. This is the complete human reference genome.
* **Output:** `GRCh38_index`. A set of 6 files with the `.bt2` extension. These files contain the indexed genome, a compressed database ready for high-speed alignment.

This logistical step allows the next phase of human DNA removal to be computationally viable, transforming a massive volume of data into an agile search tool.

### 3.2. Bowtie2 Operation

For decontamination, the **Bowtie2** aligner is used, comparing our filtered reads against the human reference genome (**GRCh38**). The strategy is based on: any read that aligns with the human genome is discarded, while reads that do not find a match (*unmapped*) are identified as microbial in origin and kept.

The `scripts/bowtie2.sh` script automates this process in four phases:

#### 1. High-Sensitivity Alignment
`bowtie2` is executed with the `--very-sensitive` parameter. This configuration is vital to maximize the detection of human DNA fragments, even those with small genetic variations relative to the reference.



#### 2. Format Optimization
The alignment generates **SAM** files (plain text), which are extremely bulky. Using **samtools**, we convert these data to **BAM** format (compressed binary) and sort them. This step saves space on the cluster and is a technical requirement for efficient searching and filtering.

#### 3. Selective Filtering by "Flags"
This is the decisive step of the process. We use the `samtools view` command with the following *flags* (numeric codes):
* **`-f 12`**: Filter that guarantees the exclusive extraction of pairs where **neither R1 nor R2 have aligned** against the human genome.
* **`-F 256`**: Avoids the extraction of secondary alignments. Sometimes, a read might seem to fit in two different places in the human genome. The program chooses the best (primary) and marks the other as secondary (256).

#### 4. Restoration to FASTQ format
Finally, the filtered data (which now contain only microbial information) are converted back to the original **compressed FASTQ (.gz)** format. 

### Final Result
The resulting files, named `_nonhuman_R1.fastq.gz` and `_nonhuman_R2.fastq.gz`, represent our **pure data**.

---

## Stage 4: *de novo* Genome Assembly (MEGAHIT)

The script used was `scripts/megahit.sh`.

### Why do we perform the assembly?

So far, our pipeline has provided us with millions of clean short reads. However, these reads are small, random fragments that, by themselves, do not give us a complete view of the sample's biology.

We need to perform this step because most of the genes we are looking for are much longer than a simple read. Assembly allows us to reconstruct the original genomic sequences to identify which bacteria are present and what metabolic capabilities they have.



### How does *de novo* assembly work?
Since we are analyzing environmental samples (fecal metagenomics), we do not know exactly which bacteria are there; therefore, we cannot use a "mold" or reference. We perform a ***de novo*** assembly (from scratch) following these steps:

* **K-mer Slicing:** The program divides the reads into even smaller fragments called *k-mers*.
* **Connection by Overlap:** If two k-mers are identical, the computer understands they come from the same DNA fragment and connects them.
* **Contig Construction:** Following these connections, the algorithm builds increasingly longer continuous sequences called **contigs**.
