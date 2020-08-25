#!/usr/bin/python
# -*- coding: utf-8 -*-
"""
Created on Wed Jul  8 13:02:12 2020

This program will take an input file of columns, scan through
the first column and add the unique values as keys in a dictionary.
Then it will go through each column of data and add the unique values
in each column as values to the key from the first column ignoring
any duplicate values. It will then save the resulting dictionary into
a .csv file. 



To do:
1. Make this work for every column. User will set an ID column to merge
on. Program will then take each column, create a list of metadata separated
by semicolons, and separate each metadata column by commas.
2. Handle extra commas ,,,,, 
3. Implement regex matching.




Parsing is designed to parse an ID in the first column and pull out a field (same field in each),
then use that field as a key. 
If you don't use the parse option, then the program will assume the first column
is the key value. 


@author: acf
"""

from collections import defaultdict
#import re
import os
import csv
import argparse
#import sys


cwd=os.getcwd()




def get_args():
    '''This function parses and return arguments passed in'''
    # Help Document Descriptions
    parser = argparse.ArgumentParser(
        formatter_class=argparse.RawDescriptionHelpFormatter,
        description=('''\
This script will take a .csv file and combine all values for a given key value into a list.
The key values must be in the first column. The values in the first column can be parsed 
to create a key by supplying a delimiter and field number.

An example usage:
0159.PersonA.Date1.STOOL,R1.STOOL.Fastq 
0159.PersonB.Date1.STOOL,R2.STOOL.Fastq
0159.PersonA.Date1.STOOL,R2.STOOL.Fastq
0159.PersonA.Date1.OW,R1.OW.Fastq

With default selections, this script will combine all matching values in column 1 to create a file:

0159.PersonA.Date1.STOOL,R1.STOOL.Fastq,R2.STOOL.Fastq
0159.PersonB.Date1.STOOL,R2.STOOL.Fastq
0159.PersonA.Date1.OW,R1.OW.Fastq

If supplying options -f 2 -d ., column 1 will be parsed to
PersonA and PersonB

and then output will be:

PersonA,R1.STOOL.Fastq,R2.STOOL.Fastq,R1.OW.Fastq
PersonB,R2.STOOL.Fastq

Duplicate values are removed but can be preserved with the -D flag. 
'''
        ))
    # Add arguments
    parser.add_argument(
        '-f', '--datafile', type=str, help='location of .csv data file', required=True, default=None)
    parser.add_argument('-n', '--fieldnumber', type = int, help = 'field in first column to use as key, numbering starting from 1  (eg 0000.AAAA.20200101.STOOL has fields 1.2.3.4)', required=False)
    parser.add_argument('-d', '--delimiter', type=str, help='delimiter character used when parsing fields in first column for key', required=False)    
    parser.add_argument('-D', '--Duplicated', help = 'if set, will keep duplicate values', required=False, default=False, action='store_true')
    parser.add_argument(
        '-o', '--outputfile', type=str, help='name of output file. default is "concat_file.csv" in current dir', required=False, default=cwd+"/concat_file.csv")
    # Array for all arguments passed to script
    args = parser.parse_args()
    
    # Assign args to variables
    datafile = args.datafile
    fieldnumber=args.fieldnumber
    delimiter=args.delimiter
    Duplicated=args.Duplicated
    outputfile=args.outputfile
    # Return all variable values
    return datafile, fieldnumber, delimiter, Duplicated, outputfile


# Match return values from get_arguments()
# and assign to their respective variables
datafile, fieldnumber, delimiter, Duplicated, outputfile = get_args()


parse=False
if fieldnumber:
    
    parse = True
    #parse = parse - 1
    parse_field = fieldnumber-1



## Variables ##

fdictionary = defaultdict()



## Functions ##

def table_dict_to_csv(output, dictionary):
    with open(output, 'wb') as f:  # Just use 'w' mode in 3.x
        w = csv.writer(f, delimiter=",")
        #w = csv.writer(sys.stderr) #for debugging, prints to stdout
        #w.writerow(["SampleID", "R1]) #writes header row
        for key, values in dictionary.iteritems():
            templist = []
            templist.append(key)
            for val in values: # this approach removes brackets in output
                templist.append(val)
            w.writerow(templist)
            

### Main Program ###

with open(datafile) as inputSheet:
    for item in inputSheet:
        if not item.strip(): continue
        if parse: #parse out key value from names in first column
            row_items=item.strip("\n")
            list_length = len(row_items) #number of columns
            
            row_items_split = row_items.split(",") #split row
            sample_key = row_items_split[0] # get first item from split row
            #print sample_key
            sample_key_parse = sample_key.split(delimiter) # split first item by delimiter
            #print sample_key_parse
            if sample_key_parse[parse_field] not in fdictionary.keys():
                fdictionary[sample_key_parse[parse_field]]=[]
                if list_length > 1:
                    for item in row_items_split[1:list_length]:
                       clean_item=item.strip('\n')
                       if Duplicated:
                           fdictionary[sample_key_parse[parse_field]].append(clean_item)
                       elif clean_item not in fdictionary[sample_key_parse[parse_field]]: #won't write duplicate value
                            fdictionary[sample_key_parse[parse_field]].append(clean_item)
            else:
                 if list_length > 1:               
                    for item in row_items_split[1:list_length]:
                        clean_item=item.strip('\n')
                        if Duplicated:
                             fdictionary[sample_key_parse[parse_field]].append(clean_item)

                        #print clean_item
                        elif clean_item not in fdictionary[sample_key_parse[parse_field]]:
                            fdictionary[sample_key_parse[parse_field]].append(clean_item)

        
     
        
        else: # no parsing of key from name
            A=item.strip("\n")
            A=A.split(",") #"\t"
            list_length = len(A)

            sample_key = A[0]
               
            if sample_key not in fdictionary.keys():
                fdictionary[sample_key]=[]#[A[1]]
                if list_length > 1:
                    for item in A[1:list_length]:
                        clean_item=item.strip('\n')
                        if Duplicated:                        
                            fdictionary[sample_key].append(clean_item)
                        
                        
                        elif clean_item not in fdictionary[sample_key]: #won't write duplicate value
                            fdictionary[sample_key].append(clean_item)
            else:
                if list_length > 1:
                    for item in A[1:list_length]:
                        clean_item=item.strip('\n')
                        if Duplicated:
                            fdictionary[sample_key].append(clean_item)
                        elif clean_item not in fdictionary[sample_key]:
                            fdictionary[sample_key].append(clean_item)


      
#print fdictionary


table_dict_to_csv(outputfile, fdictionary)