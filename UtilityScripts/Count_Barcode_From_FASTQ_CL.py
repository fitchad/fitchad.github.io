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
1. make script auto detect input file based on pattern matches
2. make it work for dual barcodes
3. Save to file
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
        '-b', '--barcodelist', type=str, help='location of tsv file containing barcode information', required=False)
    parser.add_argument(
        '-c', '--BCcolumn', type=int, help='column number containing barcode sequences from .tsv file', required=False, default=2)
    parser.add_argument(
        '-n', '--barcodecount', type=int, help='only report barcodes with counts above this cutoff. Default is 10', required=False, default=10)
    parser.add_argument(
        '-u', '--unmatchedBCs', help='Print out barcodes that were not matched to the barcode list', required=False, default=False, action='store_true')
    parser.add_argument('-o', '--outputfile', type=str, help='location of output file. Default is working dir/temp.txt', required=False, default = cwd+"/unmatched_barcodes.txt")
    # Array for all arguments passed to script
    args = parser.parse_args()
    # Assign args to variables
    fastqfile = args.fastqfile
    barcodelist = args.barcodelist
    BCcolumn = args.BCcolumn
    barcodecount=args.barcodecount
    outputfile = args.outputfile
    unmatchedBCs = args.unmatchedBCs
    # Return all variable values
    return fastqfile, barcodelist, outputfile, BCcolumn, barcodecount, unmatchedBCs

# Match return values from get_arguments()
# and assign to their respective variables
fastqfile, barcodelist, outputfile, BCcolumn, barcodecount, unmatchedBCs = get_args()
#, table, table2, outputfile = get_args()

BCcolumn = BCcolumn-1


#pattern matching to determine input file
nameI = '_I1_'

#Logic to determine file type (Index or Basespace R1/2). Could make this more robust.
with open (fastqfile, 'r') as F:
    head = [next(F) for x in range (10)]
    #print(head)
    for line in head:
        #print line
        if re.search('^([A,C,T,G,N]{8,12})$', line):
             pattern = '^([A,C,T,G,N]{8,12})$' # for Illumina Barcode (I1) files 
        else:
             pattern = '1:N:0:(\w+)$' #for single barcodes from Basespace

'''
if re.search(nameI, fastqfile):
   pattern = '^([A,C,T,G,N]{8,12})$' # for Illumina Barcode (I1) files 
else:
   pattern = '1:N:0:(\w+)$' #for single barcodes from Basespace
'''

#pattern = '1:N:0:(\w+\+\w+)$' #for dual barcodes from Basespace

lineMatch = re.compile(pattern)

tempList = []
#matchDict = defaultdict(int)
matchDict = {}
matchDict2 = {}
matchedBC = []
deleteList = []

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
            templist.append(values)
            w.writerow(templist)



#Scans FASTQ, creates a dictionary of barcodes and counts number of matches.
#prints a counter to show progress through lines of the file. 
counter = 0
with open(fastqfile, 'rb') as FASTQ:

    for line in FASTQ:
        #print line
        m = re.findall(lineMatch,line)
        if m:
            m2 = m[0]

            counter = counter+ 1
            #print counter
            matchDict[m2]=matchDict.get(m2,0)+1

#Creates a delete list for barcodes with less than defined count
if barcodecount:
    for key, value in matchDict.iteritems():
        if value < barcodecount:
            deleteList.append(key)            
#Deletes the dictionary entries with less than defined count
for item in deleteList:
    if item in matchDict:
        del matchDict[item]

#Matches dictionary of barcode counts against a list of barcodes.
with open(barcodelist, 'rb') as BCList:
    for line in BCList:

        barcode = line.split("\t")[BCcolumn]
        barcode = barcode.strip()
        #print barcode
        if barcode in matchDict.viewkeys():
            line = line.strip()
            print line, "\t", matchDict[barcode]
            matchedBC.append(barcode) # creates a list of matchedBCs
            

#Creates a copy of dictionary of all barcodes. Deletes matched barcodes
#(ie retains only unmatched barcodes)
if unmatchedBCs:
    for barcode in matchedBC:
        if barcode in matchDict.viewkeys():
            del matchDict[barcode]
     
    for key, val in matchDict.items():
        print key, "\t", val


#write out barcode matches and counts to a csv file
#table_dict_to_csv(outputfile, matchDict)
