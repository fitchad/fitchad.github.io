#!/bin/csh


#This script will read all gzip FASTQ files under the RAWDIR and create a list with the sample name, read 1 and read 2 
#file locations for each sample. This list is used in the QC pipeline. 

set PROJECT=0159_MEDBIO

#Set RUN, Sample (where output lists will be written), and Raw fastq file diretories
set RUN = TEST
set SAMDIR2 = /mnt/cmmnas02/Users/fitchad/TEST
set RAWDIR2 = /mnt/cmmnas02/Users/fitchad/$PROJECT/Sequences/Raw/$RUN


#for R1 files
find $RAWDIR2 -name "*R1*" > $SAMDIR2/R1_2.txt
#for R2 files, takes R1 file list and renames, as Illumina files only differ slightly
cat $SAMDIR2/R1_2.txt | sed 's/_R1_/_R2_/' > $SAMDIR2/R2_2.txt
#for Sample IDs
cat $SAMDIR2/R1_2.txt | rev | cut -d "/" -f1 | rev | cut -d "_" -f 1 | sed 's/-/./g' > $SAMDIR2/Sample2.txt

#pastes all the lists together properly
paste $SAMDIR2/Sample2.txt $SAMDIR2/R1_2.txt $SAMDIR2/R2_2.txt > $SAMDIR2/Sample_Fastq_List_{$RUN}.txt

#mv $SAMDIR2/Sample_Fastq_List.txt $SAMDIR2/Sample_Fastq_List_{$RUN}.txt

#Deletes intermediate files
rm $SAMDIR2/*2.txt

#printing head of final list
head $SAMDIR2/Sample_Fastq_List_{$RUN}.txt
