#!/bin/bash

PJ=0159_MEDBIO
DIR=/mnt/cmmnas02/Users/fitchad/$PJ/Sequences/QV_30/MergeMates/**/screened_fasta
OUTFILE=/mnt/cmmnas02/Users/fitchad/$PJ/0159_MEDBIO.Sequence.Count.Merged.Reads.QV30.20191219.2


rm $OUTFILE 
#will delete existing outfile. As values are only being appended below, multiple extries will be created if you rerun script
#without deleting


for file in $(ls $DIR/*fasta); do

#echo "${file##*/}"

name=`ls $file | rev | cut -f 3 -d "/" | rev`
#echo $name
echo -e "${file##*/} \t $name \t " `cat $file | grep ">M0" | wc -l` >> $OUTFILE



done


sed -i 's/ //g' $OUTFILE
