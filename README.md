# Shotgun metagenomics analysis of IBD samples

Aquest repositori conté el pipeline d’anàlisi de 114 mostres de metagenòmica shotgun procedents de l’estudi de Lee et al. (2021, Cell Host & Microbe). Les lectures s’han processat amb un flux de treball que inclou FastQC, trimming, alineament amb Bowtie2 i assemblatge amb MEGAHIT.

## Disponibilitat de les dades
Les dades de seqüenciació crues utilitzades en aquest projecte estan disponibles a la base de dades **NCBI Sequence Read Archive (SRA)** sota l'identificador de BioProject:
* **BioProject ID:** [PRJNA685168](https://www.ncbi.nlm.nih.gov/bioproject/?term=PRJNA685168).

## Etapa 1: Control de Qualitat (FastQC)

Aquest és el pas inicial i crític del pipeline. Abans de realitzar qualsevol inferència biològica, és indispensable validar la **integritat tècnica** i la fiabilitat de les dades de seqüenciació brutes.

### Automatització
S'ha utilitzat l'script `scripts/shotgunR.sh` per executar l'eina **FastQC** de forma automatitzada sobre les mostres. L'eina analitza els fitxers de lectures (`.fastq.gz`) i genera informes diagnòstics basats en els següents paràmetres:

#### 1. Per Base Sequence Quality (Escala Phred)
* **Descripció:** És el gràfic que divideix la qualitat en tres zones: Verda (Bona), Groga (Alerta) i Vermella (Dolenta).
* **Interpretació:** Mesura el **Phred Score (Q)**. Un valor de **Q30** indica que la màquina té una precisió del **99,9%** en identificar cada nucleòtid (1 error per cada 1.000 bases).
* **Context Metagenòmic:** Com que busquem gens específics (com els de l'**operó *bai***), necessitem una fidelitat absoluta. Si la qualitat cau al final de la lectura, l'informe justifica l'ús de *trimming* per evitar errors en l'assemblatge posterior.



#### 2. Per Sequence GC Content (Signatura Genòmica)
* **Descripció:** Mostra la distribució del contingut de Guanina i Citosina en totes les lectures de la mostra.
* **Interpretació:** En una mostra de microbioma complex, esperem una corba que s'assembli a una **campana de Gauss**.
* **Senyals d'alerta:** L'aparició de pics anòmals (perfils multimodals) pot indicar la presència d'un contaminant dominant o un biaix en la preparació de la biblioteca. Una corba neta confirma una barreja diversa i equilibrada de genomes bacterians.



#### 3. Per Base Sequence Content (Estabilitat Química)
* **Descripció:** Analitza la proporció de les quatre bases (A, T, C, G) al llarg de tota la lectura.
* **Interpretació:** Les quatre línies han de tendir a ser paral·leles i estables.
* **Senyals d'alerta:** Oscil·lacions al principi (posicions 1-10) són habituals pel biaix dels *primers*, però si no s'estabilitzen, indiquen problemes químics o presència massiva d'adaptadors.

#### 4. Sequence Duplication Levels (Riquesa vs. Biaix)
* **Descripció:** Mesura quantes vegades es repeteix exactament una mateixa seqüència.
* **Interpretació:** En *shotgun*, una certa duplicació és esperable, però valors extremadament alts són senyal de **biaix per PCR**.
* **Decisió tècnica:** Si la duplicació és excessiva, indica una pèrdua de la diversitat real de la mostra, cosa que podria distorsionar els perfils d'abundància bacteriana.

#### 5. Adapter Content (Neteja de Llibreria)
* **Descripció:** Cerca seqüències sintètiques utilitzades per "enganxar" l'ADN a la placa de seqüenciació.
* **Interpretació:** Qualsevol corba ascendent indica que s'està llegint l'adaptador en lloc de l'insert d'ADN bacterià.
* **Acció correctiva:** Aquesta mètrica justifica l'ús de programes com **Trimmomatic**. L'eliminació d'adaptadors és vital per evitar que **MEGAHIT** generi contigs quimèrics (falses unions d'ADN).

## Etapa 2: Trimming i Filtratge de Qualitat (Trimmomatic)

Un cop analitzada la qualitat inicial, el segon pas del pipeline consisteix a netejar les lectures brutes. Per a aquesta tasca s'ha utilitzat **Trimmomatic v0.39**, una eina que permet eliminar seqüències artificials i bases de baixa fiabilitat.

### Automatització i Lògica de l'Script
S'ha implementat l'script `scripts/trimmo_ruben.sh`, el qual utilitza un bucle `for` per processar de forma iterativa totes les mostres *paired-end* del directori d'entrada. L'script està optimitzat per a un entorn HPC amb 4 CPUs i 32GB de RAM.

### Paràmetres de Filtratge Aplicats
Dins de l'execució, s'han definit els següents filtres específics per garantir la puresa de les dades abans de l'assemblatge:

1. **ILLUMINACLIP (NexteraPE-PE.fa:2:30:10):** - Elimina els adaptadors Nextera. 
   - El valor `2` permet fins a 2 desajustaments (*mismatches*). 
   - `30` i `10` són els llindars de puntuació per confirmar que la seqüència trobada és realment un adaptador.

2. **LEADING:3 i TRAILING:3:** - Elimina les bases dels extrems (inici i final) si la seva qualitat és inferior a un Phred score de 3. Això neteja els errors més evidents de la màquina de seqüenciar.

3. **SLIDINGWINDOW:4:15:** - Escaneja la lectura amb una finestra lliscant de **4 bases**.
   - Si la qualitat mitjana de la finestra cau per sota de **15**, es talla la lectura en aquest punt. Això elimina les zones on la qualitat comença a degradar-se.

4. **MINLEN:36:** - Descarta qualsevol lectura que, després del filtratge, tingui una longitud inferior a **36 bases**. Això evita l'ús de fragments massa curts que podrien generar ambigüitats en l'assemblatge amb MEGAHIT.



### Gestió de Resultats
L'script genera quatre fitxers per cada mostra:
* **Paired (R1/R2):** Lectures que han mantingut la seva parella després del filtratge (són les que farem servir).
* **Unpaired (R1/R2):** Lectures on només un dels membres de la parella ha superat els filtres.

## Etapa 3: Eliminació de l'ADN de l'Hoste (Bowtie2)

Tot i que l'objectiu de l'estudi és el microbioma, les mostres fecals contenen una fracció variable d'ADN procedent de les cèl·lules del pacient (hoste). Aquesta etapa és crucial per "netejar" digitalment la mostra i quedar-nos només amb la informació microbiana.

### En què consisteix aquest procés?
Utilitzem l'alineador **Bowtie2 v2.4.2** per comparar totes les nostres lectures filtrades contra el genoma de referència humà (**GRCh38**).

1. **Mapeig contra l'humà:** El programa intenta "enganxar" cada lectura al genoma humà.
2. **Separació de lectures:**
   - Si una lectura coincideix amb el genoma humà, es descarta.
   - Si una lectura **NO** coincideix, significa que el seu origen és microbià (bacteris, virus o fongs).
3. **Extracció de dades netes:** Ens quedem exclusivament amb les lectures que no han alineat amb l'humà per a les anàlisis posteriors.

## 🗂️ Etapa 2.5: Creació de l'Índex del Genoma Humà

Abans de procedir a l'eliminació de les lectures de l'hoste, cal preparar el genoma de referència. El programa **Bowtie2** no treballa directament amb fitxers FASTA de seqüència bruta, sinó que requereix un format d'índex optimitzat per a la cerca ràpida.

### 🛠️ Què fa aquest script?
L'script `index.sh` executa la comanda `bowtie2-build`. Aquest procés agafa el genoma de referència humà (**GRCh38.p14**) i el transforma en una estructura de dades anomenada *Burrows-Wheeler Transform* (BWT).

* **Input:** `GCF_000001405.40_GRCh38.p14_genomic.fna` (El fitxer amb tota la seqüència de l'ADN humà).
* **Output:** `GRCh38_index` (Un conjunt de 6 fitxers petits amb extensió `.bt2`).

## 🧬 Etapa 3: Eliminació de l'ADN de l'Hoste (Bowtie2 + Samtools)

Un cop les dades estan netes de seqüències de mala qualitat, el següent pas crític en metagenòmica clínica és l'eliminació de les lectures procedents de l'hoste (humà). Aquest procés garanteix que les anàlisis posteriors es basin exclusivament en el microbioma.

### 🛠️ Lògica del Pipeline d'Alineament
L'script `bowtie2.sh` executa un flux de treball de quatre passos per a cadascuna de les 114 mostres:

#### 1. Alineament amb Bowtie2
* **Comanda:** `bowtie2 -x GRCh38_index --very-sensitive`
* **Què fa?** Compara les nostres lectures contra l'índex del genoma humà creat prèviament. L'opció `--very-sensitive` s'utilitza per maximitzar la probabilitat de trobar qualsevol fragment d'ADN humà, encara que tingui petites variacions.

#### 2. Processament amb Samtools (BAM i Ordenació)
* **Què fa?** El resultat de Bowtie2 és un fitxer `.sam` (molt gran). Utilitzem `samtools` per convertir-lo a `.bam` (format binari comprimit) i ordenar-lo. Això és necessari perquè l'ordinador pugui filtrar les dades de manera eficient.

#### 3. Filtratge de lectures "no-humanes"
* **Comanda:** `samtools view -f 12 -F 256`
* **Què fa?** Aquest és el pas clau. Mitjançant *flags* (codis numèrics), demanem al programa que ens doni **només** les lectures que **NO** han alineat contra el genoma humà (lectures *unmapped*). 
   - El flag `-f 12` extreu les parelles on ni la R1 ni la R2 han trobat coincidència amb l'humà.

#### 4. Recuperació del format FASTQ
* **Què fa?** Finalment, convertim el fitxer de bacteris filtrats (`.bam`) de nou al format original (`.fastq.gz`). Aquests fitxers resultants (`_nonhuman_R1.fastq.gz`) són els que utilitzarem per a l'assemblatge final.
