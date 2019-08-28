#!/bin/csh

#Script will collate the 'fastq_qc_log.NN.tsv' files from the QC pipeline
#into a single tsv file. Header is copied from the first file. 


set QC = 30
set PJ = 0174_Tilves
set DIR = /media/sf_fitchad_CMMNAS02/$PJ/Sequences/QV_$QC/QC_$QC #Input Directory
set DIR2 = ~/Desktop/Data/0174_Tilves #Output Directory
@ x=1
set FILE = $DIR2/{$PJ}_QC_{$QC}_Report.tsv

foreach file (`ls $DIR/fastq* `)
	if ($x == 1) then
		cat $file > $FILE
		set x = 2
	else  
		cat $file | sed -n '2,$ p' >> $FILE
endif
end

sed -i 's/\# Name\t\t\tNumRecords/SampleID\tRead\tFilter\tNumRecords/' $FILE

