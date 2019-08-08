#!/usr/bin/python

# -*- coding: utf-8 -*-
"""
Created on Wed Oct 24 13:43:35 2018

@author: acf


Program will take in an Illumina fastq file, use a regex to match the 
barcode in the header, add the barcode to a counting dictionary,
and then create .csv file that has the barcode sequences and total counts
of each barcode. Useful when looking at an undetermined file to see what 
barcodes were not demuxed. 

Barcode List has to be a TSV file containing the barcode sequence in a 
user specified column or default of <BCName>\t<BCSequence>\t<AdditionalCols>.


"""

'''
To Add:
1. make script auto detect innnnnnput file based on pattern matches
2. make it work for dual barcodes
'''

import re
import os
import csv
import argparse
import sys

cwd=os.getcwd()

def get_args():
    '''This function parses and return arguments passed in'''
    # Help Document Descriptions
    parser = argparse.ArgumentParser(
        description='')
    # Add arguments
    parser.add_argument(
        '-f', '--fastqfile', type=str, help='location of fastq file to parse', required=True)
    parser.add_argument(
        '-b', '--barcodelist', type=str, help='location of tsv file containing barcode information <BCName>\t<BCSequence>', required=False)
    parser.add_argument(
        '-c', '--BCcolumn', type=int, help='column number containing barcode sequences from .tsv file', required=False, default=2)
    #parser.add_argument(
    #    '-tt', '--table2', type=str, help='location of second summary table from KL pipeline', required=False, default=None)
    parser.add_argument('-o', '--outputfile', type=str, help='location of output file. Default is working dir/temp.txt', required=False, default = cwd+"/unmatched_barcodes.txt")
    # Array for all arguments passed to script
    args = parser.parse_args()
    # Assign args to variables
    fastqfile = args.fastqfile
    barcodelist = args.barcodelist
    BCcolumn = args.BCcolumn
    ##table2=args.table2
    outputfile = args.outputfile
    # Return all variable values
    return fastqfile, barcodelist, outputfile, BCcolumn, #table2, 

# Match return values from get_arguments()
# and assign to their respective variables
fastqfile, barcodelist, outputfile, BCcolumn = get_args()
#, table, table2, outputfile = get_args()

BCcolumn = BCcolumn-1

print fastqfile

#pattern matching to determine input file
nameI = '_I1_'

if re.search(nameI, fastqfile):
   pattern = '^([A-Z]{8,12})$' # for Illumina Barcode (I1) files 
else:
   pattern = '1:N:0:(\w+)$' #for single barcodes from Basespace


#pattern = '1:N:0:(\w+\+\w+)$' #for dual barcodes from Basespace

lineMatch = re.compile(pattern)

tempList = []
#matchDict = defaultdict(int)
matchDict = {}
matchDict2 = {}

#######################
##### Functions #######
#######################
def table_dict_to_csv(output, dictionary):
    with open(output, 'wb') as f:  # Just use 'w' mode in 3.x
        #w = csv.writer(f, delimiter=",")
        w = csv.writer(sys.stderr) #for debugging, prints to stdout
        w.writerow(["BarcodeSet","Count"]) #writes header row
        for key, values in dictionary.iteritems():
            templist = []
            templist.append(key)
            #for #val in values:
            templist.append(values)
            w.writerow(templist)




counter = 0
with open(fastqfile, 'rb') as FASTQ:

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
            #print counter
            matchDict[m2]=matchDict.get(m2,0)+1


with open(barcodelist, 'rb') as BCList:
    for line in BCList:

        barcode = line.split("\t")[BCcolumn]
        barcode = barcode.strip()
        #print barcode
        if barcode in matchDict.viewkeys():
            line = line.strip()
            print line, "\t", matchDict[barcode]
            

#This creates a second matched dict with counts above a defined level.
#Not the most memory efficient way to do this.
for key, value in matchDict.iteritems():
    if value > 9:
       matchDict2[key]=value




#write out barcode matches and counts to a csv file
#table_dict_to_csv(outputfile, matchDict)
