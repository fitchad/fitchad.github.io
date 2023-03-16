#!/usr/bin/env python3

"""

Updated 03/06/2023

@author: acf

*Code has been updated to be more cohesive...it auto detects the file type 
(basespace or local illumina) and sets a pattern to use if it determines the file 
is from basespace (name/BC sequence same line). 
local files have the name/sequence on different lines.

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

import re
import os
import csv
import argparse



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

OutputFile=outputfile
minL=6
maxL=12

##This isn't currently doing anything. 

#Logic to determine file type (Index or Basespace R1/2).
with open (fastqfile, 'r') as F:
    head = [next(F) for x in range (10)]
    #print head
    counterDictionary = {"countI":0, "countBS":0, "countBS_2":0}    

    for line in head:
        #print line
        if re.search('^([A,C,T,G,N]{%s,%s})$' % (minL, maxL), line):
            counterDictionary["countI"]=counterDictionary.get("countI",0)+1
        elif re.search('1:N:0:(\w{%s,%s})$' % (minL, maxL), line):
            counterDictionary["countBS"]=counterDictionary.get("countBS",0)+1
        elif re.search('1:N:0:(\w{%s,%s}\+\w{%s,%s})$' % (minL, maxL, minL, maxL), line):
            counterDictionary["countBS_2"]=counterDictionary.get("countBS_2",0)+1#for dual barcodes from Basespace)

    maxCount = max(counterDictionary, key=counterDictionary.get)
    print(maxCount)
    if maxCount == "countI":
        pattern = '^([A,C,T,G,N]{%s,%s})$' % (minL, maxL) # for Illumina Barcode (I1) files
    elif maxCount == "countBS":
       pattern = '1:N:0:(\w{%s,%s})$' % (minL, maxL) #for single barcodes from Basespace
    elif maxCount == "countBS_2":
        pattern = '1:N:0:(\w{%s,%s}\+\w{%s,%s})$' % (minL, maxL, minL, maxL) # for dual barcodees from basespace
    else:
        print("No pattern matches. Unsure of input file type.")
        

## Variables
#tempList = []
barcodeCountsDict = {}
barcodeMatchDict = {}
matchedBC = []
headerline=[]
uHeader=0
lineMatch = re.compile(pattern)
counter = 0

#######################
##### Functions #######
#######################
def flatten(S):
    if S == []:
        return S
    if isinstance(S[0], list):
        return flatten(S[0]) + flatten(S[1:])
    return S[:1] + flatten(S[1:])



def table_dict_to_csv(output, dictionary):
    with open(output, 'w') as f:  # Just use 'w' mode in 3.x
        w = csv.writer(f, delimiter=",")
        #w = csv.writer(sys.stderr) #for debugging, prints to stdout
        if uHeader==0:
            headerline.insert(0, "BarcodeSet")
            headerline.append("Count")
            w.writerow(headerline)
        else:
            w.writerow(["BarcodeSet","Count"]) #writes header row
        
        for key, values in sorted(dictionary.items(), key=lambda x:x[1], reverse=True):
            templist = []
            templist.append(key)
            templist.append(values)
            templist=flatten(templist)
            w.writerow(templist)

#####################################
# Main program starts here #
#####################################

#Scans FASTQ, creates a dictionary of barcodes and counts number of matches.
#prints a counter to show progress through lines of the file. 

with open(fastqfile, 'r') as FASTQ:
    for i, l in enumerate(FASTQ,1):
        pass
    linesInFile = i
    counter = linesInFile/4

    print("Total Reads in File: " + str(counter))
    FASTQ.seek(0)
    
    counterR1=counter
    for line in FASTQ:        
        if re.search('^@M[^ ]*', line):
            m = re.findall('^@M[^ ]*', line)
            if maxCount == "countI":
                barcodeMatchDict[m[0]]=[next(FASTQ, '').strip()]
            elif maxCount == "countBS" or "countBS_2":
                b=re.search(pattern, line)
                barcodeMatchDict[m[0]]=[b.group(1)]
            counterR1-=1
            if counterR1 % 50000 == 0:
                print("Remaining Sequences in Fastq1: " + str(counterR1))
                
if fastqfile2:
    with open(fastqfile2, 'r') as FASTQ2:
        for line in FASTQ2:
            if re.search('^@M[^ ]*', line):
                m = re.findall('^@M[^ ]*', line)
                
                if m[0] in barcodeMatchDict:
                    barcodeMatchDict[m[0]].append(next(FASTQ2, '').strip())                
                    counter-=1
                    if counter % 50000 == 0:
                        print("Remaining Sequences in Fastq2: " + str(counter))
            
#Creates final counting dictionary 
for value in barcodeMatchDict.values():
    join_value='+'.join(value)
    barcodeCountsDict[join_value]=barcodeCountsDict.get(join_value,0)+1


### Operations on the final barcodeCountsDict

#Removes barcodes < than defined count
if BCcount:
    barcodeCountsDict=({k:v for (k,v) in barcodeCountsDict.items() if v > BCcount})


#Matches dictionary of barcode counts against a list of barcodes, printing matches 
#to screen and file.
if BClist:
    with open(BClist, 'rb') as BCList:
        barcodeCountsDictMatch={}
        #grabbing and reformating the first header line for use in output
        for line in BCList:
            line=line.decode('utf8').strip('\n').strip('\r')
            temp=line.split("\t")
            #line=",".join(line.split('\t'))
            for item in temp:
                headerline.append(item)
            break
               
        print("Matches to Barcode List:")   
        for line in BCList:
            barcode_line=line.decode('utf8').strip('\n').strip('\r').split('\t')
            barcode = barcode_line[BCcolumn].strip()

            if barcode in barcodeCountsDict:
                #print(barcode, "\t", barcode_line, "\t", barcodeCountsDict[barcode])
                matchedBC.append(barcode) # creates a list of matchedBCs
                barcodeCountsDictMatch[barcode]=[barcode_line, barcodeCountsDict[barcode]]
    print(barcodeCountsDictMatch)
    table_dict_to_csv(OutputFile, barcodeCountsDictMatch)  
        
         

#Deletes matched barcodes (ie retains only barcodes not matched to provided list)
#and prints the unmatched barcodes / counts
if unmatchedBCs:
    barcodeCountsDict={k:v for k,v in barcodeCountsDict.items() if k not in matchedBC}
    #for barcode in matchedBC:
     #   if barcode in barcodeCountsDict:
      #      del barcodeCountsDict[barcode]
    print("Barcodes Not Matched to List: ")
    for key, val in sorted(barcodeCountsDict.items(), key=lambda x:x[1], reverse=True):
        print(key, "\t", val)
    uHeader=1
    table_dict_to_csv(OutputFile+"_unmatchedBC", barcodeCountsDict)

