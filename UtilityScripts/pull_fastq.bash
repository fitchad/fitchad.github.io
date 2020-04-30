#!/bin/bash

### Script will take in a sampleID list and multiple Fastq lists (<SampleID><R1_FileLoc><R2_FileLoc>),
### pull out the fastq files from the sampleID list and save them to a tar.gz archive.


####################################################################
# Variables to set


#Project ID. Used in the File Path. 
PJ=TEST

#DIR=$PWD
DIR=/mnt/cmmnas02/Users/fitchad/$PJ

#Directory where fastq files will be copied. 
DESTDIR=$DIR/FastqPull     #Will create below if necessary
mkdir $DESTDIR


#List of SampleIDs to match
SLIST=$DIR/Haopu.N15.SampleID

#Fastq Lists, containing the SampleID and the Fastq File paths. Typically generated in pipeline QC step.
#Can add as many as you would like, then add variable name to 'cat' command below
#if you do not have a fastq file list(s), the easiest thing to do is run the "create_list_4.csh" script to generate one (them).

FLIST1=$DIR/Fastq.H15.Test
FLIST2=$DIR/F_Fastq.H10.Test2
FLIST3=""

cat $FLIST1 $FLIST2 $FLIST3 > $DESTDIR/FLIST.TEMP

#Output archive name root. Escaping special characters. 
OUT=$PJ\_TEMP\_20191111


#####################################################################



### Using Grep to Match the list of SampleIDs in the first file to SampleIDs present in the second file

grep -w -F -h -f $SLIST $DESTDIR/FLIST.TEMP > $DESTDIR/MatchedResults.txt

#	-w whole words only
#	-F Fixed strings rather than regular expression
#	-h exclude filename from results
#	-f read from file

echo ""
echo "Number of matched SampleIDs:" $(cat $DESTDIR/MatchedResults.txt | wc -l)
MS=$(cat $DESTDIR/MatchedResults.txt | wc -l)
#MS=0 # testing

echo "Number of Unique matched SampleIDs:" $(cut -f 1 $DESTDIR/MatchedResults.txt | sort | uniq | wc -l)
UMS=$(cut -f 1 $DESTDIR/MatchedResults.txt | sort | uniq | wc -l)

cut -f 1 $DESTDIR/MatchedResults.txt | sort | uniq -d > $DESTDIR/SamplesWithDuplicateFastqSets

echo ""


if [ $MS -eq 0 ]
then
	echo "******************************************************************************"
	echo "No samples in your matched ID list. Please check punctuation used in SampleIDs"
	echo "******************************************************************************"

elif [ $MS -eq $UMS ]
then
        echo "Good. Each matched SampleID has a single set of Fastq files"

elif [ $MS -gt $UMS ]
then
        echo "*** Some sampleIDs matched more than one set of Fastq files. This may not be a problem. For example, If you resequenced some"
        echo "of the amplicons and used the same name. Make sure to determine which set of Fastq was actually used downstream"
        echo "prior to submission. ***"
else
        echo "Seems to be more unique SampleIDs then SampleIDs....this shouldn't be possible"
fi



echo ""
echo "Number of Unmatched Samples:" $(awk '{ print $1 }' $DESTDIR/MatchedResults.txt | fgrep -w -v -f - $SLIST | wc -l)
echo "Unmatched SampleIDs:"
awk '{ print $1 }' $DESTDIR/MatchedResults.txt | fgrep -w -v -f - $SLIST
awk '{ print $1 }' $DESTDIR/MatchedResults.txt | fgrep -w -v -f - $SLIST > $DESTDIR/UnmatchedSamples
echo ""


### User input for continuation of copy based on matched / unmatched SampleIDs
read -p "Would you like to continue with copy? Y or N    " VAR1



if [[ "$VAR1" = Y || "$VAR1" = y ]]
then
###Creating a single column list of files to copy
	cut -f 2 $DESTDIR/MatchedResults.txt > $DESTDIR/TEMP.FILE.LIST
	cut -f 3 $DESTDIR/MatchedResults.txt >> $DESTDIR/TEMP.FILE.LIST
###Xargs command to cp a set of files from a list containing the full path to a single destination directory
	xargs -a $DESTDIR/TEMP.FILE.LIST cp -t $DESTDIR
#		-a file
#		-t target directory

	#Removing TEMP files
	rm $DESTDIR/*TEMP*
	

	cd $DESTDIR
	tar --remove-files -cvzf $OUT.tar.gz *


else
        rm $DESTDIR/*TEMP*

	echo "***********"
	echo "Not copying"
	echo "***********"
	echo ""
	echo "Check text file logs in output directory"
	echo ""
fi

