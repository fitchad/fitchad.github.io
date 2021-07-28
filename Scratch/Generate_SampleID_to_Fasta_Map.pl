#!/usr/bin/env perl

###############################################################################

use strict;
use Getopt::Std;
use FileHandle;
use File::Basename;
use vars qw($opt_r $opt_s $opt_q $opt_p $opt_o);

getopts("r:s:q:p:o");
my $usage = "usage: 

$0 

	-r <run list>
	-s <sampleID list>
	-o <output sample id to fasta mapping file>
	[-q qv value to use, default 30]
	[-p path to fastq files, default /mnt/cmmnas02/SequencingRuns]
	

	This script will look through all the fasta (.fasta, .fa) files
	in the specified path, and generate a sample id to fasta file
	path.

	This is an optional script, but if you have a directory of
	fasta files and you think the fasta file names are consistently
	named and reflect the name of the sample the fasta file it
	represents, then this script will automatically generate
	a sample id to fasta file name.

	The output file is:

	<generated sample id> \\t <fasta path> \\n

";

if(!(
	defined($opt_r) &&
	defined($opt_s) && 
	defined($opt_o))){
	die $usage;
}


my $target_path=$opt_p;
if(!$opt_p){
$target_path='/mnt/cmmnas02/SequencingRuns';
}


my $qv_value=$opt_q;
if(!$opt_q){
$qv_value=30;
}

my $output_fname=$opt_o;
my $run_list=$opt_r;
my $sample_list=$opt_s;



print STDERR "\n";

print STDERR "QV_Value: $qv_value\n";
print STDERR "Target Path: $target_path\n";
print STDERR "Run List: $run_list\n";
print STDERR "Sample List: $sample_list\n";
print STDERR "Output Filename: $output_fname\n";

###############################################################################

#my @filelist=split "\n", `find $target_path`;

my @runlist;
my @sampleIDlist;
