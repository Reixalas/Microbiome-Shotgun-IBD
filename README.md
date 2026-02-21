# Shotgun metagenomics analysis of IBD samples

Aquest repositori conté el pipeline d’anàlisi de 114 mostres de metagenòmica shotgun procedents de l’estudi de Lee et al. (2021, Cell Host & Microbe). Atesa la gran quantitat de dades i l'elevat cost computacional de l'anàlisi metagenòmica (especialment en la fase d'assemblatge), s'ha optat per processar les mostres en **blocs de 5 en 5**. Les lectures s’han processat amb un flux de treball que inclou FastQC, trimming, alineament amb Bowtie2 i assemblatge amb MEGAHIT.

## Disponibilitat de les dades
Les dades de seqüenciació crues utilitzades en aquest projecte estan disponibles a la base de dades **NCBI Sequence Read Archive (SRA)** sota l'identificador de BioProject:
* **BioProject ID:** [PRJNA685168](https://www.ncbi.nlm.nih.gov/bioproject/?term=PRJNA685168).

## Etapa 1: Control de Qualitat (FastQC)

Abans de realitzar qualsevol inferència biològica, és indispensable validar la **integritat tècnica** i la fiabilitat de les dades de seqüenciació brutes.

### Automatització
S'ha utilitzat l'script `scripts/shotgunR.sh` per executar l'eina **FastQC** de forma automatitzada sobre les mostres. L'eina analitza els fitxers de lectures (`.fastq.gz`) i genera informes diagnòstics basats en els següents paràmetres:

#### 1. Per Base Sequence Quality (L'escala Phred)
Aquest gràfic és el primer indicador de la fiabilitat tècnica de la seqüenciació i es presenta mitjançant diagrames de caixes (boxplots) que distribueixen la qualitat en cada posició de la lectura. L'eix vertical representa el Phred Score (Q), una escala logarítmica que ens indica la probabilitat d'error en la identificació de cada nucleòtid. L'objectiu és que la pràctica totalitat de la lectura es mantingui dins de la zona verda. Si les "caixes" o les línies de mitjana cauen cap a la zona groga (alerta) o vermella (mala qualitat), la probabilitat que les lletres assignades siguin incorrectes augmenta exponencialment. En l'anàlisi de tipus shotgun, on l'objectiu final és l'assemblatge de genomes, la precisió és crítica. Les màquines de seqüenciació solen perdre qualitat a mesura que avancen cap al final de la lectura. Si aquest gràfic mostra una degradació final, utilitzarem aquesta informació per definir el punt de tall en l'etapa de trimming.



#### 2. Per Sequence GC Content (La signatura genòmica)
Aquest mòdul mesura la proporció de Guanina i Citosina en cada lectura i ens ofereix una visió global de la composició genòmica de la mostra. En metagenòmica, aquest gràfic actua com una "empremta dactilar" de la comunitat microbiana que estem analitzant. En una mostra de microbioma intestinal complex, el gràfic ha de mostrar una distribució suau que s'aproximi a una campana de Gauss. Això es deu al fet que estem seqüenciant centenars d'espècies bacterianes diferents, cadascuna amb el seu propi percentatge de GC; la superposició de tots aquests genomes crea una corba normalitzada. Una campana neta i ben definida confirma que la mostra és una barreja diversa i equilibrada de genomes.


#### 3. Per Base Sequence Content (L'estabilitat química)
Aquest mòdul examina la proporció relativa de les quatre bases nitrogenades (Adenina, Timina, Citosina i Guanina) en cada posició al llarg de la longitud total de les lectures. En una seqüenciació ideal i aleatòria, esperaríem que la quantitat de cada base fos constant i no variés segons la posició. En condicions òptimes, el gràfic ha de mostrar quatre línies pràcticament paral·leles i estables durant la major part de la lectura. Tot i que els percentatges de A-T i G-C no tenen per què ser iguals (això depèn del contingut GC de la mostra), la seva proporció no hauria d'oscil·lar significativament d'una base a la següent. L'estabilitat d'aquestes línies és un indicador que la química de la seqüenciació ha estat uniforme.

- Oscil·lacions inicials: És molt comú, i tècnicament acceptable, observar un patró de "ziga-zaga" o línies creuades en les primeres 10-12 bases. Això no es deu a una mala qualitat, sinó a l'ús de random primers (encebadors aleatoris) durant la preparació de la biblioteca de seqüenciació d'Illumina, els quals tenen una lleugera preferència d'unió per certes seqüències inicials.

- Manca d'estabilització: Si les línies continuen creuant-se o mostren canvis bruscos més enllà de la posició 15, això indica un problema. Pot ser senyal de la presència massiva d'adaptadors, d'una diversitat genètica extremadament baixa en la mostra, o d'un error en el flux químic de la màquina.

#### 4. Sequence Duplication Levels (Riquesa vs. Biaix)

Aquest mòdul analitza la redundància de la biblioteca, calculant el percentatge de lectures que apareixen més d'una vegada a la mostra. És una mètrica clau per entendre si la quantitat de dades que hem generat representa realment la diversitat de la comunitat microbiana o si és fruit d'una amplificació artificial. És normal i esperable trobar un cert nivell de duplicació, especialment si la seqüenciació és molt profunda. Això passa perquè, en llegir milions de fragments d'ADN, és estadísticament probable seqüenciar diverses vegades les regions dels genomes bacterians més abundants. Tanmateix, busquem que la gran majoria de les seqüències es trobin en la categoria de "1" (lectures úniques), fet que indica una biblioteca rica i diversa. Si el gràfic mostra un pic elevat en nivells de duplicació alts (per exemple, seqüències que es repeteixen més de 10 o 100 vegades), estem davant d'un senyal de biaix per PCR. Això passa quan, durant la preparació de la biblioteca al laboratori, uns pocs fragments d'ADN s'amplifiquen excessivament per sobre dels altres. El programa podria interpretar que un bacteri és molt abundant quan, en realitat, només ha estat sobreamplificat tècnicament.

#### 5. Adapter Content (Presència d'ADN sintètic)
Els adaptadors són fragments d'ADN sintètic utilitzats durant la preparació de la biblioteca al laboratori que no han de formar part de l'anàlisi biològica real. Qualsevol corba ascendent en aquest mòdul indica que haurem de realitzar un filtratge amb Trimmmatic. La presència d'aquests elements sol produir-se quan el fragment d'ADN és més curt que el nombre de cicles de seqüenciació, provocant que la màquina llegeixi part del material artificial. És crucial eliminar-los completament; fins i tot una presència mínima podria confondre l'assemblador MEGAHIT, portant-lo a unir seqüències artificials i crear genomes "quimèrics" o inexistents que invalidarien els resultats.

## Etapa 2: Trimming i Filtratge de Qualitat (Trimmomatic)

Després de l'avaluació inicial de qualitat mitjançant FastQC, la segona fase del pipeline se centra en el pre-processament i curació de les lectures brutes (raw reads). Per a aquesta tasca s'ha emprat Trimmomatic v0.39, una eina optimitzada per a l'eliminació d'artefactes de seqüenciació i bases de baixa fiabilitat. L'objectiu és garantir que només les dades amb una probabilitat d'error mínima alimentin l'etapa d'assemblatge de novo i eliminem els adaptadors. El dataset d'entrada es compon de parelles de fitxers (R1 i R2) per a cada mostra, fruit de la tecnologia de seqüenciació Paired-End. En aquest mètode, cada fragment de la llibreria genòmica és llegit des dels seus dos extrems: la lectura forward (R1) i la lectura reverse (R2).

El Repte de la Sincronització
Un aspecte crític durant la curació és evitar l'asincronia entre fitxers. Atès que les lectures estan aparellades, cada línia del fitxer R1 té la seva parella corresponent en la mateixa posició del fitxer R2. Si un filtre eliminés una lectura en R1 però mantingués la seva parella en R2, els fitxers quedarien desfasats, provocant errors fatals en els algorismes d'assemblatge posteriors (com MEGAHIT), que intentarien emparellar seqüències sense relació biològica.

Per mitigar aquest risc, s'ha implementat l'script scripts/trimmo_ruben.sh. Aquest utilitza un bucle for que presenta ambdós fitxers simultàniament a Trimmomatic, permetent que el programa avaluï la qualitat de cada parella en temps real i prengui decisions coordinades.

Gestió i Classificació de Resultats
Com a resultat d'aquest processament sincronitzat, Trimmomatic genera quatre fluxos de dades per cada mostra, garantint la integritat del trencaclosques genòmic:

Paired (R1/R2): Lectures supervivents on ambdós membres de la parella han superat els llindars de qualitat. Aquestes constitueixen les dades principals per a l'assemblatge, ja que conserven la informació de distància original.

Unpaired (R1/R2): Lectures "òrfenes" on només un dels membres ha superat el control de qualitat. Tot i contenir seqüències vàlides, s'han segregat i descartat en aquest pipeline per mantenir la màxima coherència i rigor en la construcció dels contigs.

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

## 🧩 Etapa 4: Assemblatge de Genomes *de novo* (MEGAHIT)

Un cop obtingudes les lectures d'alta qualitat i lliures de contaminació humana, el següent pas crític és l'**assemblatge**. En aquesta etapa, unim les lectures curtes (reads) per formar fragments d'ADN molt més llargs i continus anomenats **contigs**.

### 🛠️ Lògica de l'Script d'Automatització
S'ha dissenyat l'script `megahit_ruben.sh` per processar de manera seqüencial les 114 mostres mitjançant un bucle `for`. Aquest script està optimitzat per a la computació d'alt rendiment (HPC) amb les següents especificacions:

* **Gestió de Recursos (SLURM):** S'han assignat **32GB de RAM** i **4 CPUs**, recursos indispensables per gestionar la complexitat dels grafs de de Bruijn que genera l'assemblador.
* **Walltime (24:00:00):** S'ha definit un límit de temps de 24 hores com a mesura de seguretat. L'assemblatge és el procés més intensiu del pipeline i aquest marge assegura que les mostres més riques en biodiversitat es completin sense interrupcions del sistema.
* **Variables d'Entorn:** S'han exportat les variables `LC_ALL=C` i `LANG=C` per evitar errors de compatibilitat de llenguatge durant el processament de dades binàries.



### ⚙️ Configuració de MEGAHIT
Per a la reconstrucció dels genomes, s'ha utilitzat **MEGAHIT v1.2.9** amb una configuració específica per a microbiomes complexos:

1.  **`--presets meta-large`:** Aquesta és la decisió tècnica més rellevant de l'etapa. Aquest mode està optimitzat per a metagenomes complexos (com els de femta en pacients amb IBD). Ajusta els paràmetres de l'algorisme per capturar tant els organismes molt abundants com aquells que es troben en baixa proporció.
2.  **Estratègia de k-mers:** El programa utilitza una sèrie iterativa de k-mers per resoldre amb precisió les regions repetitives de l'ADN bacterià.
3.  **Organització de sortida:** Cada mostra genera la seva pròpia carpeta (`megahit_$BASE`) que conté el fitxer resultant més important: **`final.contigs.fa`**.
