#!/usr/bin/python

# -*- coding: utf-8 -*-
"""
Created on Thu Jan  4 16:39:55 2018

@author: acf
"""



import sys
import csv
import argparse
from collections import defaultdict
import re
import os

#returning working directory
cwd=os.getcwd()

def get_args():
    '''This function parses and return arguments passed in'''
    # Help Document Descriptions
    parser = argparse.ArgumentParser(
        description='')
    # Add arguments
    parser.add_argument(
        '-s', '--samplelist', type=str, help='location of list of samples to retain', required=True)
    parser.add_argument(
        '-f', '--fastqlist', type=str, help='location of list containing sample name and raw sequence location', required=True)
    parser.add_argument(
        '-t', '--table', type=str, help='location of .csv summary table from KL pipeline', required=False, default=None)
    parser.add_argument(
        '-tt', '--table2', type=str, help='location of second summary table from KL pipeline', required=False, default=None)
    parser.add_argument('-o', '--outputfile', type=str, help='location of output file. Default is working dir/temp.txt', required=False, default = cwd+"/temp.txt")
    # Array for all arguments passed to script
    args = parser.parse_args()
    # Assign args to variables
    samplelist = args.samplelist
    fastqlist = args.fastqlist
    table = args.table
    table2=args.table2
    outputfile = args.outputfile
    # Return all variable values
    return samplelist, fastqlist, table, table2, outputfile

# Match return values from get_arguments()
# and assign to their respective variables
samplelist, fastqlist, table, table2, outputfile = get_args()

##Setting output file location

#if outputfile:
#    filelocation=outputfile


def table_dict(table):
    #with open(table, 'rb') as T:
    tableDict=defaultdict(list)
    for line in table:
        #tableDict[line[0]]=line[1], line[2]
        tableDict[line[0]]=line[1:]
    return tableDict
        
def table_writer(filelocation, table):
    with open(filelocation, 'wb') as f:  # Just use 'w' mode in 3.x
        w = csv.writer(f, delimiter=",")
        #w = csv.writer(sys.stderr) #for debugging, prints to stdout
        #w.writerow(["SampleID",tableName,tableName2]) #writes header row
        for key, values in table.iteritems():
            templist = []
            templist.append(key)
            for val in values:
                templist.append(val)
            w.writerow(templist)
    

###Method will only match samples from the fastq list that exactly match
###the names in the input sample list.
###pushes matchedlist to a dictionary, then writes to a csv file. I did this 
###since I already had a method to write a dictionary to csv.

def match_samples(samplelist, fastqlist):
    samlist = []
    matchedlist = []
    with open(samplelist, 'rb') as SL:
        for line in SL:
            line = line.strip("\n")
            samlist.append(line)
    
        with open(fastqlist, 'rb') as FL:
            for line in FL:
                splitline = line.split("\t")
                #print splitline
                if splitline[0] in samlist:
                    #print line.strip("\n")
                    line=line.strip("\n")
                    line2 = line.split("\t")
                    matchedlist.append(line2[0:])
        #print samlist
        #list_writer(matchedlist)
        x = table_dict(matchedlist)
        table_writer(outputfile,x)

###Method should match all permutations of a sample (if in standard naming format)
###name and print a list of samples / fastq file locations
###

def match_samples_all_replicates(samplelist, fastqlist):
    samlist = []
    matchedlist = []
    with open(samplelist, 'rb') as SL:
        for line in SL:
            line = line.strip("\n")
            samplepattern = re.findall("\w+\.\w+\.\w+\.\w+", line)
            if samplepattern:
                str1=''.join(samplepattern)
                if str1 not in samlist:
                    samlist.append(str1)

        with open(fastqlist, 'rb') as FL:
            for line in FL:
                splitline = line.split("\t")
                samplepattern = re.findall("\w+\.\w+\.\w+\.\w+", splitline[0])
                if samplepattern:
                    str2=''.join(samplepattern)
                    if str2 in samlist:
                        #print line.strip("\n")
                        line=line.strip("\n")
                        line2 = line.split("\t")
                        matchedlist.append(line2[0:])

        x = table_dict(matchedlist)
        table_writer(outputfile,x)

match_samples(samplelist, fastqlist)
#match_samples_all_replicates(samplelist, fastqlist)

#list_writer()
