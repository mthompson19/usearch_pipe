#!/bin/bash
#SBATCH --job-name=usearch16s
#SBATCH -n 2
#SBATCH -N 1
#SBATCH --output usearch16s.out
#SBATCH --error usearch16s.err
#SBATCH -p penglab-48core

#Active Qiime
source activate qiime2-2021.8

# This is a script to run 16S analysis using USEARCH

# Navigate to working directory
cd /work/mat19/usearchtest 

#Naviage to raw_reads data

#Quality 

echo "Checking the quality of raw reads..."

mkdir ./fastq_eestats

for fq in *.fastq; do 

usearch -fastq_eestats2 $fq -output ./fastq_eestats/$fq -length_cutoffs 50,300,10
done

#Trim forward and reverse reads to 200bp

echo "Trimming reads to 200bp..."
for fq in *.fastq; do

NAME=$(basename $fq .fastq)
usearch -fastx_truncate ${fq} -trunclen 200 -fastqout ${NAME}_200bp.fastq
done

#Merge reads 
echo "Merge reads"
usearch -fastq_mergepairs $fq -relabel @ -fastq_maxdiffs 5 -fastqout ./200bp_merged.fq -report ./merge_200bp_report.txtq

usearch -fastq_mergepairs *R1.fastq -relabel @ -fastq_maxdiffs 10 -fastq_pctid 80 -fastqout ./200bp_merged.fq -report ./merge_200bp_report.txt

#Filter reads
echo "filter reads"
usearch -fastq_filter 200bp_merged.fq -fastq_maxee 1.0 -fastq_minlen 150 -fastaout filtered.fa

#Dereplicate reads 
echo "duplicate reads"
usearch -fastx_uniques filtered.fa -fastaout uniques.fa -sizeout -relabel Uniq

#Denoise 
echo "denoise" 
usearch -unoise3 uniques.fa -zotus zotus.fa

#ZOTU table 
echo "ZOTU table" 
usearch -otutab 200bp_merged.fq -zotus zotus.fa -otutabout zotutab.txt -biomout zotutab.json -mapout zmap.txt -notmatched unmapped.fa -dbmatched zotus_with_sizes.fa -sizeout -threads 10

#Import ZOTU to Qiime
echo "Import ZOTU to Qiime"
qiime tools import --input-path zotus.fa --output-path zotus.qza --type 'FeatureData[Sequence]'

#Qiime Taxonomy 
echo "Qiime Taxonomy"
qiime feature-classifier classify-sklearn \
 --i-classifier silva-138-99-515-806-nb-classifier.qza \
 --i-reads zotus.qza \
 --o-classification zotu_16S_taxonomy.qza

#Export to tsv
echo "export to tsv"
qiime tools export --input-path zotu_16S_taxonomy.qza --output-path 16S_taxonomy_tsv

#done
