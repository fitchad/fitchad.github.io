# -*- coding: utf-8 -*-
"""
Created on Wed Oct 24 13:43:35 2018

@author: acf


Program will take in an Illumina fastq file, use a regex to match the 
barcode in the header, add the barcode to a counting dictionary,
and then create .csv file that has the barcode sequences and total counts
of each barcode. Useful when looking at an undetermined file to see what 
barcodes were not demuxed. 

#****Important Note: This script is currently only for a basespace created FASTQ
#file, as those files include the barcodes in the header. For local MiSeq demuxed runs, 
#3 files are created, including one for I1 which is the actual barcode file. No barcodes
#are written to the header for locally produced files.  
"""

'''
To Add:
1. select basespace or local demux files
2. import and match our barcode list so we can determine missed BCs.
3. Make command line program
'''

import re
import os
import csv
import argparse


def get_args():
    '''This function parses and return arguments passed in'''
    # Help Document Descriptions
    parser = argparse.ArgumentParser(
        description='')
    # Add arguments
    parser.add_argument(
        '-f', '--fastqfile', type=str, help='location of fastq file to parse', required=True)
    parser.add_argument(
        '-b', '--barcodelist', type=str, help='location of list containing barcode information <BCName>\t<BCSequence>', required=False)
    #parser.add_argument(
     #   '-t', '--table', type=str, help='location of .csv summary table from KL pipeline', required=False, default=None)
    #parser.add_argument(
    #    '-tt', '--table2', type=str, help='location of second summary table from KL pipeline', required=False, default=None)
    parser.add_argument('-o', '--outputfile', type=str, help='location of output file. Default is working dir/temp.txt', required=False, default = cwd+"/temp.txt")
    # Array for all arguments passed to script
    args = parser.parse_args()
    # Assign args to variables
    fastqfile = args.fastqfile
    barcodelist = args.barcodelist
    ##table = args.table
    ##table2=args.table2
    outputfile = args.outputfile
    # Return all variable values
    return fastqfile, barcodelist, outputfile#, table, table2, 

# Match return values from get_arguments()
# and assign to their respective variables
fastqfile, barcodelist, outputfile = get_args()
#, table, table2, outputfile = get_args()




















cwd=os.getcwd()

fastqFOR = "/home/acf/Desktop/sf_QIIME-SHARED/Temp/Undetermined_S0_L001_R1_001.fastq"

#fastqFOR = "/home/acf/Desktop/Undetermined_Small.fastq"

#pattern = '1:N:0:(\w+\+\w+)$' #for dual barcodes
pattern = '1:N:0:(\w+)$' #for single barcodes
lineMatch = re.compile(pattern)

tempList = []
#matchDict = defaultdict(int)
matchDict = {}
matchDict2 = {}
outputfile = cwd+"/20190805_unmatched_barcodes.csv"



def table_dict_to_csv(output, dictionary):
    with open(output, 'wb') as f:  # Just use 'w' mode in 3.x
        w = csv.writer(f, delimiter=",")
        #w = csv.writer(sys.stderr) #for debugging, prints to stdout
        w.writerow(["BarcodeSet","Count"]) #writes header row
        for key, values in dictionary.iteritems():
            templist = []
            templist.append(key)
            #for #val in values:
            templist.append(values)
            w.writerow(templist)




counter = 0
with open(fastqFOR, 'rb') as FASTQ:

    for line in FASTQ:
        #print line
        m = re.findall(lineMatch,line)
        if m:
            m2 = m[0]
            #if m2 in matchDict:
            #    matchDict[m2]=+c
            #else:
            #    matchDict[m2]=1
            counter = counter+ 1
            print counter
            matchDict[m2]=matchDict.get(m2,0)+1


#This creates a second matched dict with counts above a defined level.
#Not the most memory efficient way to do this.
for key, value in matchDict.iteritems():
    if value > 9:
       matchDict2[key]=value

#print matchDict2
table_dict_to_csv(outputfile, matchDict)
