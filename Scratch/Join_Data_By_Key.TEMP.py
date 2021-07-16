#!/usr/bin/python
# -*- coding: utf-8 -*-
"""
Created on Wed Jul  8 13:02:12 2020
Updated on 01/04/21

This program will take an input file of columns and add the unique values 
of the first column as keys in a dictionary. After adding a key, 
it will go through the remaining row of data and add the unique values
in the row as values to the key from the first column
If a key in the first column is already present as a dictionary key
it will add its values to the existing key. 

It will then save the resulting dictionary into
a .csv file. 



To do:
1. Make this work for every column. User will set an ID column to merge
on. Program will then take each column, create a list of metadata separated
by semicolons, and separate each metadata column by commas.
2. Handle extra commas ,,,,, 
3. Implement regex matching.




Parsing is designed to parse a key value from the first column, pulling out a field (same field in each),
from the first column then using that field value as a key. 
If you don't use the parse option, then the program will assume the full value in the first column
is the key. 


@author: acf
"""

from collections import defaultdict
import os
import csv
import argparse
import re

cwd=os.getcwd()

def get_args():
    '''This function parses and return arguments passed in'''
    # Help Document Descriptions
    parser = argparse.ArgumentParser(
        formatter_class=argparse.RawDescriptionHelpFormatter,
        description=('''\
This script will take a CSV or TSV file and combine all values for a given 
key value into a {key1:[val1,val2], key2:[val1,val2,val3], etc} dictionary.

The key values must be in the first column. The values in the first column can be parsed 
to create a key by supplying a delimiter and field number. The full, original value
of the parsed key can be retained as a value with the -R flag.

Rows can contain numbers of columns. All values for a key in a given row 
will be added to the output for that key.
If you do not want this behavior your should cut the columns you want into a new file.

There is some basic logic (i.e. counting the number of commas or tabs) used to
determine the file type. Output filetype is the same as input. 

An example usage:
0159.PersonA.Date1.STOOL,R1.STOOL.Fastq 
0159.PersonB.Date1.STOOL,R2.STOOL.Fastq
0159.PersonA.Date1.STOOL,R2.STOOL.Fastq
0159.PersonA.Date1.OW,R1.OW.Fastq

With default selections, this script will combine all matching values in column 1 to create a file:

0159.PersonA.Date1.STOOL,R1.STOOL.Fastq,R2.STOOL.Fastq
0159.PersonB.Date1.STOOL,R2.STOOL.Fastq
0159.PersonA.Date1.OW,R1.OW.Fastq

If supplying options -n 2 -d ., column 1 will be parsed to
PersonA and PersonB

and then output will be:

PersonA,R1.STOOL.Fastq,R2.STOOL.Fastq,R1.OW.Fastq
PersonB,R2.STOOL.Fastq

If supplying -n 2 -d . and -R, the full column 1 will be retained as output after parsing:

PersonA,0159.PersonA.Date1.STOOL,R1.STOOL.Fastq,R2.STOOL.Fastq,0159.PersonA.Date1.OW,R1.OW.Fastq
PersonB,0159.PersonB.Date1.STOOL,R2.STOOL.Fastq


Duplicate values for a given key are discarded by default 
but can be preserved with the -D flag. 

Values for each key can be sorted prior to writing to the .csv 
by using the -S flag
'''
        ))
    # Add arguments
    parser.add_argument(
        '-f', '--datafile', type=str, help='location of .csv data file', required=True, default=None)
    parser.add_argument('-n', '--fieldnumber', type=int, help='field in first column to use as key, numbering starting from 1  (eg 0000.AAAA.20200101.STOOL has fields 1.2.3.4)', required=False)
    parser.add_argument('-d', '--delimiter', type=str, help='delimiter character used when parsing key from first column', required=False)
    parser.add_argument('-R', '--Retain', help='when parsing key from col1 value, the full col1 value will be kept as first entry to key', required=False, default=False, action='store_true')    
    parser.add_argument('-D', '--Duplicated', help='keep duplicated values', required=False, default=False, action='store_true')
    parser.add_argument('-S', '--Sort', help='sort values prior to writing to csv', required=False, default=False, action='store_true')
    parser.add_argument('-I', '--IndivFile', help='output each Key:value set to its own file', required=False, action='store_true')    
    parser.add_argument(
        '-o', '--outputfile', type=str, help='name of output file. default is "joined_file_by_key.csv" in current dir', required=False, default=cwd+"/joined_file_by_key.csv")
    # Array for all arguments passed to script
    args = parser.parse_args()
    
    # Assign args to variables
    datafile = args.datafile
    fieldnumber=args.fieldnumber
    delimiter=args.delimiter
    Retain=args.Retain
    Duplicated=args.Duplicated
    Sort=args.Sort
    IndivFile=args.IndivFile
    outputfile=args.outputfile
    # Return all variable values
    return datafile, fieldnumber, delimiter, Retain, Duplicated, Sort, IndivFile, outputfile


# Match return values from get_arguments()
# and assign to their respective variables
datafile, fieldnumber, delimiter, Retain, Duplicated, Sort, IndivFile, outputfile = get_args()


parse=False
if fieldnumber:   
    parse = True
    parse_field = fieldnumber-1

if Retain:
    start_val=0
else:
    start_val=1



#Logic to determine file type (csv or tsv).
with open (datafile, 'r') as F:
    
    for i, l in enumerate(F,1):
                pass
    F.seek(0)

    if i < 10:
        head = [next(F) for x in range (i)]
    else:
        head = [next(F) for x in range (10)]
        
    counterDictionary = {"countCSV":0, "countTSV":0 }    

    for line in head:
        if re.search(',', line):
            numberOfMatches=re.findall(',', line)
            lengthOfMatches=len(numberOfMatches)
            counterDictionary["countCSV"]=counterDictionary.get("countCSV",0)+lengthOfMatches
        if re.search('\t', line):
            numberOfMatches=re.findall('\t', line)
            lengthOfMatches=len(numberOfMatches)          
            counterDictionary["countTSV"]=counterDictionary.get("countTSV",0)+lengthOfMatches
    
    if counterDictionary["countTSV"] != counterDictionary["countCSV"]:
    
        maxCount = max(counterDictionary, key=counterDictionary.get)
           
        if maxCount is "countCSV":
            fileType = ","
        elif maxCount is "countTSV":
           fileType = "\t"
    else:
        fileType = ","
        print "\n"
        print "Unable to determine delimiter, will try ','. Please check output."








## Variables ##

keyDictionary = defaultdict(list)
df_length=0
### Main Program ###

with open(datafile) as inputSheet:

    for item in inputSheet:
        df_length=df_length+1
        if not item.strip(): continue #skip empty rows
        if parse: #parse out key value from names in first column
            row_items=item.strip("\n")
            list_length = len(row_items) #number of columns
            
            row_items_split = row_items.split(fileType) #split row
            sample_key = row_items_split[0] # get first item from split row
            try:            
                sample_key_parse = sample_key.split(delimiter)  # split first item by delimiter

                if sample_key_parse[parse_field] not in keyDictionary.keys():
                    keyDictionary[sample_key_parse[parse_field]]=[]
                    if list_length > 1:                        
                        for item in row_items_split[start_val:list_length]:
                           clean_item=item.strip('\n')
                           if Duplicated:
                               keyDictionary[sample_key_parse[parse_field]].append(clean_item)
                           elif clean_item not in keyDictionary[sample_key_parse[parse_field]]: #won't write duplicate value
                                keyDictionary[sample_key_parse[parse_field]].append(clean_item)
                else:
                     if list_length > 1:               
                        for item in row_items_split[start_val:list_length]:
                            clean_item=item.strip('\n')
                            if Duplicated:
                                 keyDictionary[sample_key_parse[parse_field]].append(clean_item)
                                 
                            elif clean_item not in keyDictionary[sample_key_parse[parse_field]]:
                                keyDictionary[sample_key_parse[parse_field]].append(clean_item)  
                    
                    
                
            except IndexError: #catch improper sampleIDs and skip
                print "Skipping sample key", sample_key, " it lacks proper fields to parse"
                continue


        
        
        else: # no parsing of key from name
            
            #this enters duplicate values in the list (ie its not checking, just appending)
            # although it does work and is much less code.
            '''
            items = item.strip().split(",")
            keyDictionary[items[0]] += items[1:]
            '''

            A=item.strip("\n").split(fileType) #"\t"
            list_length = len(A)

            sample_key = A[0]
               
            if sample_key not in keyDictionary.keys():
                keyDictionary[sample_key]=[]
                if list_length > 1:
                    for item in A[1:list_length]:
                        clean_item=item.strip('\n')
                        if Duplicated:                        
                            keyDictionary[sample_key].append(clean_item)
                        
                        elif clean_item not in keyDictionary[sample_key]: #won't write duplicate value
                            keyDictionary[sample_key].append(clean_item)
            else:
                if list_length > 1:
                    for item in A[1:list_length]:
                        clean_item=item.strip('\n')
                        if Duplicated:
                            keyDictionary[sample_key].append(clean_item)
                        elif clean_item not in keyDictionary[sample_key]:
                            keyDictionary[sample_key].append(clean_item)


print "\n"
print "Number of input rows: ", df_length
print "Number of unique keys: ", len(keyDictionary)


#### writing output ####

if IndivFile:
    for key in sorted(keyDictionary):
        outputfile="%s.csv" % key
        with open(outputfile, 'wb') as f:  # Just set 'w' mode in 3.x
            w = csv.writer(f, delimiter=fileType)
                #w = csv.writer(sys.stderr) #for debugging, prints to stdout
            templist=[]
            templist2=[]
            templist.append(key)
            for val in keyDictionary[key]: # this approach removes brackets in output
                templist2.append(val)
            if Sort:
                templist2.sort()
            for val2 in templist2:
                templist.append(val2)
            w.writerow(templist)
        

else:
    with open(outputfile, 'wb') as f:  # Just set 'w' mode in 3.x
        w = csv.writer(f, delimiter=fileType)
            #w = csv.writer(sys.stderr) #for debugging, prints to stdout
        for key, values in keyDictionary.iteritems():
            templist=[]
            templist2=[]
            templist.append(key)
            for val in values: # this approach removes brackets in output
                templist2.append(val)
            if Sort:
                templist2.sort()
            for val2 in templist2:
                templist.append(val2)
            w.writerow(templist)
    

