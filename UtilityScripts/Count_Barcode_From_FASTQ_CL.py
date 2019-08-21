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

2. make it work for dual barcodes - input cols, barcode matching
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
        '-b', '--BClist', type=str, help='location of tsv file containing barcode information', required=False)
    parser.add_argument(
        '-c', '--BCcolumn', type=int, help='column number containing barcode sequences from .tsv file', required=False, default=2)
    parser.add_argument(
        '-n', '--BCcount', type=int, help='only report barcodes with counts above this cutoff. Default is 10', required=False, default=10)
    parser.add_argument(
        '-u', '--unmatchedBCs', help='Print out barcodes that were not matched to the barcode list', required=False, default=False, action='store_true')
    parser.add_argument(
        '-v', '--verbose', help='Print out counter', required=False, default=False, action='store_true')
    parser.add_argument(
        '-o', '--outputfile', type=str, help='location of output file. Default is working dir/BarcodesFromUndetermined.txt', required=False, default = cwd+"/BarcodesFromUndetermined.txt")
    # Array for all arguments passed to script
    args = parser.parse_args()
    # Assign args to variables
    fastqfile = args.fastqfile
    BClist = args.BClist
    BCcolumn = args.BCcolumn
    BCcount=args.BCcount
    outputfile = args.outputfile
    unmatchedBCs = args.unmatchedBCs
    verbose = args.verbose
    # Return all variable values
    return fastqfile, BClist, outputfile, BCcolumn, BCcount, unmatchedBCs, verbose

# Match return values from get_arguments()
# and assign to their respective variables
fastqfile, BClist, outputfile, BCcolumn, BCcount, unmatchedBCs, verbose = get_args()


BCcolumn = BCcolumn-1


#Logic to determine file type (Index or Basespace R1/2).
with open (fastqfile, 'r') as F:
    head = [next(F) for x in range (10)]
    #print head
    counterDictionary = {"countI":0, "countBS":0, "countBS_2":0}    

    for line in head:
        #print line
        if re.search('^([A,C,T,G,N]{8,12})$', line):
            counterDictionary["countI"]=counterDictionary.get("countI",0)+1
        elif re.search('1:N:0:(\w{8,12})$', line):
            counterDictionary["countBS"]=counterDictionary.get("countBS",0)+1
        elif re.search('1:N:0:(\w{8,12}\+\w{8,12})$', line):
            counterDictionary["countBS_2"]=counterDictionary.get("countBS_2",0)+1#for dual barcodes from Basespace)

    maxCount = max(counterDictionary, key=counterDictionary.get)

    if maxCount is "countI":
        pattern = '^([A,C,T,G,N]{8,12})$' # for Illumina Barcode (I1) files
    elif maxCount is "countBS":
       pattern = '1:N:0:(\w{8,12})$' #for single barcodes from Basespace
    elif maxCount is "countBS_2":
        pattern = '1:N:0:(\w{8,12}\+\w{8,12})$'
    else:
        print "No pattern matches. Unsure of input file type." 


#pattern = '1:N:0:(\w+\+\w+)$' #for dual barcodes from Basespace
if verbose:
  newSeqMatch = '^@M0'
  countMatch = re.compile(newSeqMatch)

## Variables
tempList = []
matchDict = {}
#matchDict2 = {}
matchedBC = []
deleteList = []
lineMatch = re.compile(pattern)


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


#####################################
# Main program starts here #
#####################################

#Scans FASTQ, creates a dictionary of barcodes and counts number of matches.
#prints a counter to show progress through lines of the file. 
counter = 0

with open(fastqfile, 'rb') as FASTQ:
  if verbose:
      for i, l in enumerate(FASTQ):
        pass
      linesInFile = i+1
      counter = linesInFile/4
      print "Total Reads in File: " + str(linesInFile)
      FASTQ.seek(0)
  for line in FASTQ:
          if verbose:
            n = re.findall(countMatch, line)
            if n:
              counter = counter - 1

              print "Remaining Sequences: " + str(counter)

          m = re.findall(lineMatch,line)
          if m:
            m2 = m[0]

            matchDict[m2]=matchDict.get(m2,0)+1

#Creates a delete list for barcodes with less than defined count
if BCcount:
    for key, value in matchDict.iteritems():
        if value < BCcount:
            deleteList.append(key)            
#Deletes the dictionary entries with less than defined count
    for item in deleteList:
        if item in matchDict:
            del matchDict[item]

#Matches dictionary of barcode counts against a list of barcodes.
if BClist:
    with open(BClist, 'rb') as BCList:
        print "Matches to Barcode List:"
        for line in BCList:
    
            barcode = line.split("\t")[BCcolumn]
            barcode = barcode.strip()
            #print barcode
            if barcode in matchDict.viewkeys():
                line = line.strip()
                print line, "\t", matchDict[barcode]
                matchedBC.append(barcode) # creates a list of matchedBCs
            
#Deletes matched barcodes (ie retains only barcodes not matched to provided list)
if unmatchedBCs:
    for barcode in matchedBC:
        if barcode in matchDict.viewkeys():
            del matchDict[barcode]
    print "Barcodes Not Matched to List: "
    for key, val in matchDict.items():
        print key, "\t", val


#write out barcode matches and counts to a csv file
#Need to update code. Only outputs remaining BCs in matchdict, after deleting matches
#to the barcode list. Probably need to save barcode matches as tuples in a list and 
#then output those if they exist. 
#table_dict_to_csv(outputfile, matchDict)
