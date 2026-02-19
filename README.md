# Shotgun metagenomics analysis of IBD samples

Aquest repositori conté el pipeline d’anàlisi de 114 mostres de metagenòmica shotgun procedents de l’estudi de Lee et al. (2021, Cell Host & Microbe). Les lectures s’han processat amb un flux de treball que inclou FastQC, trimming, alineament amb Bowtie2 i assemblatge amb MEGAHIT.

## Disponibilitat de les dades
Les dades de seqüenciació crues utilitzades en aquest projecte estan disponibles a la base de dades **NCBI Sequence Read Archive (SRA)** sota l'identificador de BioProject:
* **BioProject ID:** [PRJNA685168](https://www.ncbi.nlm.nih.gov/bioproject/?term=PRJNA685168).

## Etapa 1: Control de Qualitat (FastQC)

Aquest és el pas inicial i crític del pipeline. Abans de realitzar qualsevol inferència biològica, és indispensable validar la **integritat tècnica** i la fiabilitat de les dades de seqüenciació brutes.

### 🛠️ Automatització
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

## ✂️ Etapa 2: Trimming i Filtratge de Qualitat (Trimmomatic)

Un cop analitzada la qualitat inicial, el segon pas del pipeline consisteix a netejar les lectures brutes. Per a aquesta tasca s'ha utilitzat **Trimmomatic v0.39**, una eina que permet eliminar seqüències artificials i bases de baixa fiabilitat.

### 🛠️ Automatització i Lògica de l'Script
S'ha implementat l'script `scripts/trimmo_ruben.sh`, el qual utilitza un bucle `for` per processar de forma iterativa totes les mostres *paired-end* del directori d'entrada. L'script està optimitzat per a un entorn HPC amb 4 CPUs i 32GB de RAM.

### ⚙️ Paràmetres de Filtratge Aplicats
Dins de l'execució, s'han definit els següents filtres específics per garantir la puresa de les dades abans de l'assemblatge:

1. **ILLUMINACLIP (NexteraPE-PE.fa:2:30:10):** - Elimina els adaptadors Nextera. 
   - El valor `2` permet fins a 2 desajustaments (*mismatches*). 
   - `30` i `10` són els llindars de puntuació per confirmar que la seqüència trobada és realment un adaptador.

2. **LEADING:3 i TRAILING:3:** - Elimina les bases dels extrems (inici i final) si la seva qualitat és inferior a un Phred score de 3. Això neteja els errors més evidents de la màquina de seqüenciar.

3. **SLIDINGWINDOW:4:15:** - Escaneja la lectura amb una finestra lliscant de **4 bases**.
   - Si la qualitat mitjana de la finestra cau per sota de **15**, es talla la lectura en aquest punt. Això elimina les zones on la qualitat comença a degradar-se.

4. **MINLEN:36:** - Descarta qualsevol lectura que, després del filtratge, tingui una longitud inferior a **36 bases**. Això evita l'ús de fragments massa curts que podrien generar ambigüitats en l'assemblatge amb MEGAHIT.



### 📦 Gestió de Resultats
L'script genera quatre fitxers per cada mostra:
* **Paired (R1/R2):** Lectures que han mantingut la seva parella després del filtratge (són les que farem servir).
* **Unpaired (R1/R2):** Lectures on només un dels membres de la parella ha superat els filtres.
