#!/usr/bin/python
import csv
import os
import argparse
from collections import defaultdict
#import matplotlib.pyplot as plt

#__author__ = 'Adam Fitch'

cwd=os.getcwd()


####Variables#####
#matchList=[] #list of matched sample names from the summary table that appear in metadata list
#matchDict={} #dictionary that holds the unique combined metadata columns as keys and the sampleIDs that map to them.

############################
####Argument Parser#########
############################

def get_args():
    '''This function parses and return arguments passed in'''
    # Help Document Descriptions
    parser = argparse.ArgumentParser(
        description='')
    # Add arguments
    parser.add_argument(
        '-t', '--table', type=str, help='location of .csv summary table from KL pipeline', required=False, default=None)
    parser.add_argument(
        '-tt', '--table2', type=str, help='location of second summary table from KL pipeline', required=False, default=None)
    parser.add_argument('-ttt', '--table3', type=str, help= 'location of table 3', required=False, default=None)
    parser.add_argument('-c', '--column', type = int, help = 'column of values to parse for comparison. same for all tables', required=False, default = 1)
    parser.add_argument(
        '-o', '--outputfile', type=str, help='location file to write output. default is "tablecomp.csv" in current dir', required=False, default=cwd+"/tablecomp.csv")
    # Array for all arguments passed to script
    args = parser.parse_args()
    
    # Assign args to variables
    table = args.table
    table2=args.table2
    table3=args.table3
    column=args.column
    outputfile=args.outputfile
    # Return all variable values
    return table, table2, table3, column, outputfile


# Match return values from get_arguments()
# and assign to their respective variables
table, table2, table3, column, outputfile = get_args()


#######################
#####Functions#########
#######################

#Returns table name from the directory supplied at command line
def table_name_parse(tableDir):
    if not tableDir:
        exit
    splitTableName = tableDir.split("/")[-1:] #parses only last item, ie filename
    for item in splitTableName: #return as a string
        return item

#Returns a dictionary with sample names as key and count as value. Input is a 
#Mothur generated summary table
def table_dict(table, column):
    with open(table, 'rb') as T:
        tableDict={}
        next(T) #skip header line
        for line in T:
            splitLine=line.split("\t")
            tableDict[splitLine[0]]=splitLine[column]
        return tableDict


##Old table comparison function, will likely delete
"""
def table_comparison(table, table2, *table3):
    combinedDict = defaultdict(list)    
    if table3:
        table3 = table3[0]
    if table and table2 and not table3:
        b = table.viewkeys() & table2.viewkeys()
        f = table.viewkeys() ^ table2.viewkeys()

    else:
        b = table.viewkeys() & table2.viewkeys() & table3.viewkeys()
    for item in b:
        combinedDict[item].append(int(table[item]))
        combinedDict[item].append(int(table2[item]))
        if table3:
            combinedDict[item].append(int(table3[item]))
    for item in f:
        if item in table.viewkeys():
            combinedDict[item].append(int(table[item]))
            combinedDict[item].append(0)
        else:
            combinedDict[item].append(0)
            combinedDict[item].append(int(table2[item]))
            
    return combinedDict
"""

####Creates a dictionary that contains the samples names and count values for
####up to 3 tables. 
def table_comparison(table, table2, *table3):
    combinedDict = defaultdict(list)    

    if table and table2:
        b = table.viewkeys() & table2.viewkeys() #List with Intersection of keys
        f = table.viewkeys() ^ table2.viewkeys() #List with keys unique to one of the tables

    for item in b:
        combinedDict[item].append(int(table[item]))
        combinedDict[item].append(int(table2[item]))

    for item in f:
        if item in table.viewkeys(): # if item in table1
            combinedDict[item].append(int(table[item]))
            combinedDict[item].append(0)
        else: #else item is in table 2
            combinedDict[item].append(0)
            combinedDict[item].append(int(table2[item]))
    if table3: # if a third table supplied
        table3 = table3[0] #optional arguments are a tuple, must pull first element
        b = combinedDict.viewkeys() & table3.viewkeys()
        f = combinedDict.viewkeys() ^ table3.viewkeys()
        for item in b:
            combinedDict[item].append(int(table3[item]))
        if f:
            for item in f:
                if item in combinedDict.viewkeys(): #if item in combined, can't be in table3
                    combinedDict[item].append(0)
                else: #must be in table3
                    combinedDict[item].append(0)
                    combinedDict[item].append(0)
                    combinedDict[item].append(int(table3[item]))
    return combinedDict




def table_writer(output):
    with open(output, 'wb') as f:  # Just use 'w' mode in 3.x
        w = csv.writer(f, delimiter=",")
        #w = csv.writer(sys.stderr) #for debugging, prints to stdout

        if table3:
            w.writerow(["SampleID",tableName,tableName2,tableName3]) #writes header row
        else:
            w.writerow(["SampleID",tableName,tableName2]) #writes header row
        for key, values in tableComp.iteritems():
            templist = []
            templist.append(key)
            for val in values:
                templist.append(val)
            w.writerow(templist)


###Parsing table names and storing for later use in csv header
if table:
    tableName = table_name_parse(table)
if table2:
    tableName2 = table_name_parse(table2)
if table3:
    tableName3 = table_name_parse(table3)


###Creating dictionaries from input tables {sample name : reads}
if table:
    a=table_dict(table, column)
if table2:
    b=table_dict(table2, column)
if table3:
    c=table_dict(table3, column)              


#match_samples(tableDict, metadata)


if table2 and not table3:
    tableComp = table_comparison(a,b)
if table2 and table3:
    tableComp = table_comparison(a,b,c)

if outputfile:
    table_writer(outputfile)

