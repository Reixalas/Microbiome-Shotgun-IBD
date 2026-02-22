# Shotgun Metagenomics Analysis of IBD Samples

Aquest repositori conté el *pipeline* d’anàlisi bioinformàtica per al processament de **114 mostres** de metagenòmica *shotgun* procedents de l’estudi de **Lee et al. (2021)**, publicat a *Cell Host & Microbe*. 

L'objectiu principal de l'anàlisi és l'estudi del microbioma intestinal en pacients amb Malaltia Inflamatòria Intestinal (IBD). Atesa la gran càrrega de dades, s'ha implementat una estratègia de processament optimitzada en **blocs de 5 mostres**. 



---

## Disponibilitat de les dades

Les dades de seqüenciació crues utilitzades en aquest projecte estan dipositades a la base de dades **NCBI Sequence Read Archive (SRA)**. Es poden consultar i descarregar mitjançant l'identificador de BioProject:

* **BioProject ID:** [PRJNA685168](https://www.ncbi.nlm.nih.gov/bioproject/?term=PRJNA685168)

---

## Preparació de l'Entorn Computacional

Abans d'executar qualsevol etapa del *pipeline*, cal assegurar que el programari estigui correctament activat i configurat per treballar al clúster. Per fer-ho, se segueix aquest protocol:

* **`module load miniconda3`**: Habilita el gestor de paquets Conda al sistema. 
* **`source ~/.bashrc`**: Actualitza i refresca la configuració del terminal.
* **`conda activate shotgun1`** (o `megahit` segons l'etapa): Activa l'entorn virtual on resideixen les eines específiques (MEGAHIT, Bowtie2, Samtools, etc.).



---
## Etapa 1: Control de Qualitat (FastQC)

Abans de realitzar qualsevol inferència biològica, és indispensable validar la **integritat tècnica** i la fiabilitat de les dades de seqüenciació brutes.
S'ha utilitzat l'script `scripts/shotgunR.sh` per executar l'eina **FastQC** de forma automatitzada. Aquest procés analitza els fitxers de lectures (`.fastq.gz`) i genera informes diagnòstics basats en quatre mètriques clau:

---

#### 1. Per Base Sequence Quality
Aquest gràfic és el primer indicador de la fiabilitat tècnica. Utilitza diagrames de caixes (*boxplots*) per representar la qualitat en cada posició de la lectura.
* **Interpretació:** L'eix vertical representa el Phred Score (Q), una escala logarítmica que ens indica la probabilitat d'error en la identificació de cada nucleòtid. L'objectiu és que la pràctica totalitat de la lectura es mantingui dins de la zona verda. Si les "caixes" o les línies de mitjana cauen cap a la zona groga (alerta) o vermella (mala qualitat), la probabilitat que les lletres assignades siguin incorrectes augmenta exponencialment. Les màquines de seqüenciació solen perdre qualitat a mesura que avancen cap al final de la lectura. Si aquest gràfic mostra una degradació final, utilitzarem aquesta informació per definir el punt de tall en l'etapa de trimming.

#### 2. Per Sequence GC Content 
Mesura la proporció de Guanina i Citosina, actuant com una "empremta dactilar" de la comunitat microbiana.
* **Interpretació:** Aquest mòdul mesura la proporció de Guanina i Citosina en cada lectura i ens ofereix una visió global de la composició genòmica de la mostra. En una mostra de microbioma intestinal complex, el gràfic ha de mostrar una distribució suau que s'aproximi a una campana de Gauss. Això es deu al fet que estem seqüenciant centenars d'espècies bacterianes diferents, cadascuna amb el seu propi percentatge de GC; la superposició de tots aquests genomes crea una corba normalitzada. 

#### 3. Per Base Sequence Content
Examina la proporció de les quatre bases (A, T, C, G) al llarg de la lectura.
* **Interpretació:** En condicions òptimes, el gràfic ha de mostrar línies paral·leles i estables. És normal observar un patró de "ziga-zaga" en les primeres 10-12 bases a causa dels *random primers* d'Illumina. Si les línies no s'estabilitzen més enllà de la base 15, pot ser un senyal de presència massiva d'adaptadors o baixa diversitat genètica.

#### 4. Adapter Content
Detecta fragments d'ADN artificial (adaptadors) utilitzats durant la preparació de la biblioteca.
* **Interpretació:** Qualsevol corba ascendent en aquest mòdul indica que haurem de realitzar un filtratge amb Trimmmatic. La presència d'aquests elements sol produir-se quan el fragment d'ADN és més curt que el nombre de cicles de seqüenciació, provocant que la màquina llegeixi part del material artificial. És crucial eliminar-los completament; fins i tot una presència mínima podria confondre l'assemblador MEGAHIT, portant-lo a unir seqüències artificials i crear genomes "quimèrics" o inexistents que invalidarien els resultats.
---

## Etapa 2: Filtratge (Trimmomatic)

Un cop avaluada la qualitat inicial amb **FastQC**, la segona fase del *pipeline* se centra en el pre-processament. Per a aquesta tasca s'ha emprat **Trimmomatic v0.39**, una eina especialitzada en l'eliminació d'artefactes de seqüenciació i la neteja de bases de baixa fiabilitat. L'objectiu és evitar la introducció d'errors durant l'assemblatge *de novo* en etapes posteriors.

### Script
L'eficiència de l'script `scripts/trimmo_ruben.sh` rau en la implementació d'un **bucle `for`**, que permet processar de forma iterativa i automatitzada les 5 mostres del projecte. L'script identifica automàticament cada parella de fitxers (R1 i R2) i executa Trimmomatic en mode **PE (Paired-End)**. Aquest mode avalua ambdues lectures simultàniament per prendre decisions coordinades sobre la integritat del fragment.

### Paràmetres de Filtratge
S'han definit els següents mòduls per garantir la puresa de les dades abans de l'assemblatge:

| Paràmetre | Descripció Tècnica |
| :--- | :--- |
| **ILLUMINACLIP:NexteraPE-PE.fa:2:30:10** | Eliminació d'adaptadors Nextera. S'utilitza un llindar de **2** *mismatches* i puntuacions de **30** (palíndrom) i **10** (simple) per evitar falsos positius. |
| **LEADING:3** / **TRAILING:3** | Retalla les bases dels extrems (inici i final) si la seva qualitat és inferior a un **Phred score de 3**. |
| **SLIDINGWINDOW:4:15** | Filtre dinàmic que analitza la lectura en finestres de 4 bases. Si la qualitat mitjana del segment cau per sota de **15**, la lectura es talla en aquest punt. |
| **MINLEN:36** | Qualsevol lectura que, després de la curació, tingui una longitud inferior a **36 bases** és descartada per evitar ambigüitats en l'assemblatge. |

### Resultats
Com a producte d'aquest processament, el programa genera quatre fluxos de dades per cada mostra.

* **Paired (R1/R2):** Ambdós membres han superat els controls de qualitat. Seran les dades que utilitzarem.
* **Unpaired (R1/R2):** Només un membre de la parella ha superat els filtres. Es descarten.


---

## Etapa 3: Eliminació de l'ADN de l'Hoste (Bowtie2)

Tot i que l'objectiu de l'estudi és el microbioma intestinal, les mostres fecals contenen una fracció variable d'ADN procedent de les cèl·lules del pacient (hoste). Per poder analitzar exclusivament el contingut microbià, cal filtrar aquestes lectures humanes.

### 3.1. Indexació del Genoma de Referència
Abans de realitzar el filtratge, és imprescindible "preparar" el genoma humà perquè l'ordinador pugui processar-lo de manera eficient. El fitxer original del genoma és un llistat massiu de milers de milions de caràcters que no permet una cerca directa. Si haguéssim de buscar cada lectura dins del fitxer de text pla, el procés trigaria setmanes i requeriria una quantitat de memòria RAM inabastable.

L'script `index.sh` executa la comanda `bowtie2-build`, la qual comprimeix el genoma i l'organitza en una estructura de dades optimitzada:

* **Input:** `GCF_000001405.40_GRCh38.p14_genomic.fna`. És el genoma de referència humà complet.
* **Output:** `GRCh38_index`. Un conjunt de 6 fitxers amb extensió `.bt2`. Aquests fitxers contenen el genoma indexat, una base de dades comprimida a punt per a l'alineament d'alta velocitat.

Aquest pas logístic és el que permet que la següent fase d'eliminació de l'ADN humà sigui viable a nivell computacional, transformant un volum de dades gegantí en una eina de cerca àgil.


### 3.2. Funcionament de Bowtie2

Per a la descontaminació, s'utilitza l'alineador **Bowtie2 v2.4.2** comparant les lectures filtrades contra el genoma de referència humà (**GRCh38**). L'estratègia es basa en: qualsevol lectura que s'alineï amb el genoma humà es descarta, mentre que les lectures que no troben coincidència (*unmapped*) s'identifiquen com d'origen microbià i es conserven.

L'script `scripts/bowtie2_ruben.sh` automatitza aquest procés en quatre fases:

#### 1. Alineament d'Alta Sensibilitat
S'executa `bowtie2` amb el paràmetre `--very-sensitive`. Aquesta configuració és vital per maximitzar la detecció de fragments d'ADN humà, inclús aquells amb petites variacions genètiques respecte a la referència.

#### 2. Optimització de Formats
L'alineament genera fitxers **SAM** (text pla), que són extremadament voluminosos. Mitjançant **samtools**, convertim aquestes dades a format **BAM** (binari comprimit) i les ordenem. Aquest pas estalvia espai al clúster i és un requisit tècnic per realitzar cerques i filtratges eficients.

#### 3. Filtratge Selectiu per "Flags"
Aquest és el pas decisiu del procés. Utilitzem la comanda `samtools view` amb els següents *flags* (codis numèrics):
* **`-f 12`**: Filtre que garanteix l'extracció exclusiva de les parelles on **ni la R1 ni la R2 han alineat** contra el genoma humà.
* **`-F 256`**: Evita l'extracció d'alineaments secundaris. A vegades, una lectura podria semblar que encaixa en dos llocs diferents del genoma humà. El programa tria el millor (primari) i marca l'altre com a secundari (256).

#### 4. Restauració al format FASTQ
Finalment, les dades filtrades (que ja només contenen informació microbiana) es converteixen de nou al format original **FASTQ comprimit (.gz)**. 

---

### Resultat Final
Els fitxers resultants, anomenats `_nonhuman_R1.fastq.gz` i `_nonhuman_R2.fastq.gz`, representen les nostres **dades pures**.

## 🧩 Etapa 4: Assemblatge de Genomes *de novo* (MEGAHIT)

Per què fem l'assemblatge?
Fins ara, el nostre pipeline ens ha proporcionat milions de lectures curtes (reads) netes. Tanmateix, aquestes lectures són fragments aleatoris i petits que, per si sols, no ens donen una visió completa de la biologia de la mostra.

L'assemblatge és el pas on passem de tenir "confeti" d'ADN a tenir "paràgrafs" amb sentit. Necessitem fer aquest pas perquè la majoria de gens que busquem (com els de l'operó bai) són molt més llargs que una simple lectura. L'assemblatge ens permet reconstruir les seqüències genòmiques originals per poder identificar quins bacteris estan presents i quines capacitats metabòliques tenen.

🛠️ Com funciona l'assemblatge de novo?
Com que estem analitzant mostres ambientals (metagenòmica de femta), no sabem exactament quins bacteris hi ha; per tant, no podem fer servir un "motlle" o referència. Realitzem un assemblatge de novo (des de zero).

Trossejament en k-mers: El programa divideix les lectures en fragments encara més petits anomenats k-mers.

Connexió per solapament: Si dos k-mers són idèntics, l'ordinador entén que provenen del mateix fragment d'ADN i els connecta.

Construcció de Contigs: Seguint aquestes connexions, l'algorisme construeix seqüències contínues cada cop més llargues anomenades contigs.
