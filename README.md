# Shotgun metagenomics analysis of IBD samples

Aquest repositori conté el pipeline d’anàlisi de 114 mostres de metagenòmica shotgun procedents de l’estudi de Lee et al. (2021, Cell Host & Microbe). Les lectures s’han processat amb un flux de treball que inclou FastQC, trimming, alineament amb Bowtie2 i assemblatge amb MEGAHIT.

## Disponibilitat de les dades
Les dades de seqüenciació crues utilitzades en aquest projecte estan disponibles a la base de dades **NCBI Sequence Read Archive (SRA)** sota l'identificador de BioProject:
* **BioProject ID:** [PRJNA685168](https://www.ncbi.nlm.nih.gov/bioproject/?term=PRJNA685168).

## Etapa 1: Control de Qualitat (FastQC)

Aquest és el primer pas del pipeline. Abans de fer cap anàlisi biològica, hem de saber si les dades de seqüenciació són fiables.

### Què fa aquest script?
L'script `shotgunR.sh` executa l'eina **FastQC** de forma automatitzada. FastQC llegeix els fitxers de seqüències (`.fastq.gz`) i genera un informe visual (en format HTML) que ens indica:
1. **Qualitat de les bases (Phred Score):** Ens diu si la màquina de seqüenciar ha llegit bé cada lletra (A, T, C, G).
2. **Presència d'adaptadors:** Detecta si encara hi ha trossos de seqüències artificials utilitzades al laboratori que hem de treure.
