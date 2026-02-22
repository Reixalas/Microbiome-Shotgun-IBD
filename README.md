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

Després de l'avaluació inicial amb **FastQC**, la segona fase del pipeline se centra en el pre-processament i curació de les lectures brutes (*raw reads*). Per a aquesta tasca s'ha emprat **Trimmomatic v0.39**, una eina optimitzada per a l'eliminació d'artefactes de seqüenciació i bases de baixa fiabilitat. L'objectiu primordial és garantir que només les dades amb una probabilitat d'error mínima alimentin l'etapa d'assemblatge *de novo*.

### Automatització i Execució
L'eficiència de l'script `scripts/trimmo_ruben.sh` rau en la implementació d'un **bucle for**, el qual permet processar de forma iterativa i automatitzada totes les mostres del projecte. L'script està programat per identificar automàticament cada parella de fitxers (R1 i R2) dins del directori de seqüències brutes.



Un cop identificades, executa Trimmomatic en mode **PE (Paired-End)**, avaluant ambdues lectures (Forward i Reverse - R1 i R2) simultàniament per prendre decisions coordinades en temps real sobre la integritat de la parella de fragments.

### Configuració i Paràmetres de Filtratge
Dins de l'execució, s'han definit els següents mòduls per garantir la puresa de les dades:

* **ILLUMINACLIP:NexteraPE-PE.fa:2:30:10**: Mòdul de detecció d'adaptadors Nextera.
    * El **2** permet fins a dos errors (*mismatches*) en la cerca.
    * El **30** (palíndrom) i el **10** (simple) són els llindars de puntuació requerits per confirmar que es tracta d'un adaptador i no de DNA real.
* **LEADING:3** i **TRAILING:3**: Retalla les bases dels extrems (inici i final) si la seva qualitat és inferior a un Phred score de 3, eliminant els errors més evidents dels sensors de la màquina.
* **SLIDINGWINDOW:4:15**: Filtre dinàmic de qualitat. Analitza la lectura en finestres de 4 bases i la talla si la qualitat mitjana del segment cau per sota de 15. Això elimina les zones on la precisió de la seqüenciació comença a degradar-se.
* **MINLEN:36**: Estableix que qualsevol lectura que, després de la curació, tingui una longitud inferior a 36 bases sigui descartada. Fragments tan curts podrien generar ambigüitats i falsos alineaments durant l'assemblatge.

### Gestió de Resultats
Com a resultat d'aquest processament, Trimmomatic genera quatre fluxos de dades per cada mostra que garanteixen la integritat del procés:

1.  **Paired (R1/R2)**: Lectures supervivents on ambdós membres (FORWARD i REVERSE) han superat els controls. Són les dades "netes" i sincronitzades que s'utilitzaran per a l'assemblatge.
2.  **Unpaired (R1/R2)**: Lectures "òrfenes" on només un membre de la parella ha superat els filtres. Tot i ser seqüències vàlides, es segreguen i es descarten en aquest pipeline per mantenir el rigor i la coherència espacial en la reconstrucció dels *contigs*.


## Etapa 3: Eliminació de l'ADN de l'Hoste (Bowtie2)

Tot i que l'objectiu de l'estudi és el microbioma, les mostres fecals contenen una fracció variable d'ADN procedent de les cèl·lules del pacient (hoste). Abans de poder filtrar l'ADN de l'hoste, és imprescindible "preparar" el genoma humà perquè l'ordinador pugui treballar amb ell. El fitxer original del genoma és un llistat massiu de milers de milions de caràcters que no permet una cerca directa eficient. Per això, utilitzem Bowtie2 per crear un índex. Si haguéssim de buscar cada lectura, una per una, dins del fitxer de text del genoma humà, el procés trigaria setmanes i requeriria una quantitat de memòria RAM impossible de gestionar.

L'script index.sh executa la comanda bowtie2-build, comprimeix el genoma i l'organitza en una estructura de dades optimitzada.

Input (La matèria bruta): GCF_000001405.40_GRCh38.p14_genomic.fna. És el genoma de referència humà complet, un fitxer de text pla molt pesat.

Output (L'eina de cerca): GRCh38_index. Un conjunt de 6 fitxers amb extensió .bt2. Aquests fitxers contenen el genoma comprimit i "indexat", a punt per ser utilitzat com a base per a l'alineament.

És el pas logístic que converteix una base de dades gegant en una eina de cerca d'alta velocitat, permetent que el pas següent (l'eliminació de l'ADN humà) sigui viable a nivell computacional.


Per a aquesta descontaminació, utilitzem l'alineador Bowtie2 v2.4.2 comparant les nostres lectures filtrades contra el genoma de referència humà (GRCh38). L'estratègia es basa en un principi d'exclusió: qualsevol lectura que s'alineï amb el genoma humà es descarta, mentre que les lectures que no troben coincidència (lectures unmapped) s'identifiquen com d'origen microbià i es conserven per a l'assemblatge.

L'script scripts/bowtie2_ruben.sh automatitza aquest procés en quatre fases clau:

1. Alineament d'Alta Sensibilitat
S'executa la comanda bowtie2 utilitzant el paràmetre --very-sensitive. Aquesta configuració és vital per maximitzar la probabilitat de detectar qualsevol fragment d'ADN humà, fins i tot aquells que presentin petites variacions genètiques o mutacions respecte a la referència. L'objectiu és ser extremadament rigorosos per no arrossegar contaminació humana a les etapes posteriors.

2. Processament i Optimització de Formats
L'alineament genera fitxers en format SAM, que són fitxers de text pla extremadament voluminosos. Mitjançant samtools, convertim aquestes dades a format BAM (binari comprimit) i les ordenem. Aquest pas no només estalvia espai de disc en el clúster, sinó que és un requisit tècnic perquè el programari pugui realitzar cerques i filtratges de manera eficient.

3. Filtratge Selectiu per "Flags"
Aquest és el pas decisiu del procés. Utilitzem la comanda samtools view amb els codis numèrics o flags següents:

-f 12: Aquest filtre garanteix que extreurem exclusivament les parelles de lectures on ni la R1 ni la R2 han alineat contra el genoma humà.

-F 256: S'utilitza per evitar l'extracció d'alineaments secundaris, assegurant que només treballem amb les dades primàries i úniques.

4. Restauració al format FASTQ
Finalment, les dades filtrades (que ara ja contenen només informació microbiana) es converteixen de nou al format original FASTQ comprimit (.gz). Aquests fitxers resultants, anomenats _nonhuman_R1.fastq.gz i _nonhuman_R2.fastq.gz, representen les nostres "dades netes" i definitives, llistes per ser utilitzades en la reconstrucció de l'operó bai mitjançant l'assemblatge de genomes.

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
