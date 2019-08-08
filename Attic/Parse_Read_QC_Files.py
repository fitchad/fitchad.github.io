# -*- coding: utf-8 -*-
"""
Spyder Editor

This script will read in a cat'ed combined Fastq reads log file (the QC
files generated during pipeline) and capture/output lines that match
certain criteria. For example, I used it to capture just the "raw" read
initial input and the "paired" reads remaining.
"""




import re
import os
import csv


FastqStats = "/home/acf/Desktop/sf_QIIME-SHARED/Fastq.Logs.Combined"
FastqTrim = "/home/acf/Desktop/Fastq.Trim"



def line_to_file(line, outfile):
    with open(outfile, 'a') as f:  # Jus
        #w = csv.writer(f)
        #w = csv.writer(sys.stderr) #for debugging, prints to stdout
        f.write(line) #writes header row
        #f.write('\n')


counter = 0
with open(FastqStats, 'rb') as FASTQ:

    for line in FASTQ:
        if re.match("#", line):
            if counter<1:
                line_to_file(line, FastqTrim)
                counter=+1 
        if re.findall("raw", line):
            line_to_file(line, FastqTrim)
        if re.findall("paired", line):
            line_to_file(line, FastqTrim)
            
            
            
            
