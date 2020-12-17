#!/usr/bin/python

# -*- coding: utf-8 -*-
"""

Updated 10/10/2019

@author: acf


Program will take in an Illumina fastq file, use a regex to match the 
barcode (in the header if basepace derived or in index file if from
MiSeq Reporter), add the barcode to a counting dictionary,
and then create .csv file that has the barcode sequences and total counts
of each barcode. Useful when looking at an undetermined file to see what 
barcodes were not demuxed. 

Barcode List has to be a TSV file containing the barcode sequence in a 
user specified column or default of <BCName>\t<BCSequence>\t<AdditionalCols>.


For Barcode pairs, the barcode list file should contain a single column
containing the barcodes as BC1+BC2 in the order of the index files created. 
BC1 is I1, BC2 is I2. Also keep in mind the orientation of the barcode sequence.


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
        '-f2', '--fastqfile2', type=str, help='location of second barcode fastq file to parse', required=False)
    parser.add_argument(
        '-b', '--BClist', type=str, help='location of tsv file containing barcode information', required=False)
    parser.add_argument(
        '-c', '--BCcolumn', type=int, help='column number containing barcode sequences from .tsv file', required=False, default=2)
    parser.add_argument(
        '-n', '--BCcount', type=int, help='only report barcodes with counts above this cutoff. Default is 10', required=False, default=10)
    parser.add_argument(
        '-u', '--unmatchedBCs', help='Print out barcodes that were not matched to the barcode list', required=False, default=False, action='store_true')
    parser.add_argument(
        '-o', '--outputfile', type=str, help='location of output file. Default is working dir/BarcodesFromUndetermined.txt', required=False, default = cwd+"/BarcodesFromUndetermined.txt")
    # Array for all arguments passed to script
    args = parser.parse_args()
    # Assign args to variables
    fastqfile = args.fastqfile
    fastqfile2 = args.fastqfile2
    BClist = args.BClist
    BCcolumn = args.BCcolumn
    BCcount=args.BCcount
    outputfile = args.outputfile
    unmatchedBCs = args.unmatchedBCs
    # Return all variable values
    return fastqfile, fastqfile2, BClist, outputfile, BCcolumn, BCcount, unmatchedBCs

# Match return values from get_arguments()
# and assign to their respective variables
fastqfile, fastqfile2, BClist, outputfile, BCcolumn, BCcount, unmatchedBCs = get_args()


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

## Variables
tempList = []
matchDict = {}
matchDict2BCs = {}
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
if not fastqfile2:
    with open(fastqfile, 'rb') as FASTQ:
        for i, l in enumerate(FASTQ):
            pass
        linesInFile = i+1
        counter = linesInFile/4

        print "Total Reads in File: " + str(counter)
        FASTQ.seek(0)
        for line in FASTQ:
              m = re.findall(lineMatch,line)
              if m:
                m2 = m[0]
                counter=counter-1
                if counter % 500000 == 0:
                    print "Remaining Sequences: " + str(counter)
                matchDict[m2]=matchDict.get(m2,0)+1

if fastqfile2:
    with open(fastqfile, 'r') as FASTQ:
        keyF1 = ""
        valueF1 = ""
        boolmatch = 0
        for i, l in enumerate(FASTQ):
                pass
        linesInFile = i+1
        counter = linesInFile/4

        print "Total Reads in File: " + str(counter)
        FASTQ.seek(0)
              
        for line in FASTQ:        
   
            if (boolmatch==1):
                if re.search('^([A,C,T,G,N]{8,12})$', line):
                    b= re.findall('^([A,C,T,G,N]{8,12})$', line)
                    valueF1 = b[0]
    
                    matchDict2BCs[keyF1]=[valueF1]
                    boolmatch = 0
            if re.search('^(@M[^ ]*)', line) and boolmatch==0:
                boolmatch = 1
                m = re.findall('^(@M[^ ]*)', line)  
                keyF1 = m[0]

    with open(fastqfile2, 'r') as FASTQ2:
        keyF2 = ""
        valueF2 = ""
        boolmatch = 0
        for line in FASTQ2:
            if keyF2 is "":
                exit
            elif matchDict2BCs[keyF2]:
                if (boolmatch==1):
                    if re.search('^([A,C,T,G,N]{8,12})$', line):
                        b= re.findall('^([A,C,T,G,N]{8,12})$', line)
                        valueF2 = b[0]
                        matchDict2BCs[keyF2].append(valueF2)
                        boolmatch = 0
                        keyF2 = ""
                
            if re.search('^(@M[^ ]*)', line) and boolmatch ==0:
                m = re.findall('^(@M[^ ]*)', line)
                boolmatch = 1
                keyF2 = m[0]

                
    for values in matchDict2BCs:
       counter=counter-1
       if counter % 500000 == 0:
           print "Remaining Sequences: " + str(counter)

       TempList = matchDict2BCs[values]
       x= TempList[0] + "+" + TempList[1]
       matchDict[x]=matchDict.get(x,0)+1




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
