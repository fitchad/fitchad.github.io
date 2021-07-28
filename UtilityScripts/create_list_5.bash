#!/bin/bash


#This script will read all gzip FASTQ files under the RAWDIR and create a list with the sample name, read 1 and read 2 
#file locations for each sample. This list is used in the QC pipeline. 

PROJECT=0333_money
#set PJ to search for all samplesIDs beginning with this code. Leave blank for all samples in run. 
PJ=0333

#Set RUN, Sample (where output lists will be written), and Raw fastq file diretories

for RUN in \
TEST1 \
TEST2 
do

SAMDIR2=/mnt/scratch/TEMP_ACF/$PROJECT/
RAWDIR2=/mnt/cmmnas02/SequencingRuns/$RUN/Run

#for R1 files
find $RAWDIR2 -name "$PJ*\_R1\_*" > $SAMDIR2/TEMPL_R1_2.txt
#for R2 files, takes R1 file list and renames, as Illumina files only differ slightly
cat $SAMDIR2/TEMPL_R1_2.txt | sed 's/_R1_/_R2_/' > $SAMDIR2/TEMPL_R2_2.txt
#for Sample IDs
cat $SAMDIR2/TEMPL_R1_2.txt | rev | cut -d "/" -f1 | rev | cut -d "_" -f 1 | sed 's/-/./g' > $SAMDIR2/TEMPL_Sample2.txt

#pastes all the lists together properly
paste $SAMDIR2/TEMPL_Sample2.txt $SAMDIR2/TEMPL_R1_2.txt $SAMDIR2/TEMPL_R2_2.txt > $SAMDIR2/Sample_Fastq_List_${RUN}.txt

#mv $SAMDIR2/Sample_Fastq_List.txt $SAMDIR2/Sample_Fastq_List_${RUN}.txt

#Deletes intermediate files
rm $SAMDIR2/TEMPL*.txt

#printing head of final list
head $SAMDIR2/Sample_Fastq_List_${RUN}.txt

done
