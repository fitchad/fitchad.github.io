#!/usr/bin/env perl

#To Do:
#1. add the ability to change the file extension?

###############################################################################

use strict;
use warnings;
use Getopt::Std;
use FileHandle;
use File::Basename;
use File::Find;
use vars qw($opt_r $opt_s $opt_o $opt_i $opt_c);
use Cwd;

getopts("r:s:o:ic");
my $usage = "usage: 

$0 

	-r <run path list>
	-s <sampleID list>
	-o <output sample id to fasta mapping file>
	-i [interpret sampleID list as a list of studyIDs]
	-c [include controls in output if using studyID list option]
	

	This script will look through all the paired.for.fasta files
	in the specified path(s), and generate a sampleID to paired.for.fasta file
	path for the listed sampleIDs. 

	The run list file -r should be the full paths of where you want to
	look for the paired.for.fasta files, for example:
	/mnt/cmmnas02/SequencingRuns/20180934_efef_dfdfe__RN-0000/QC/QV_30/MergeMates/screened_fasta

	The sampleID list should be exact matches to sampleIDs, unless using -i option.
	
	The -i studyID option changes the interpretation of the sampleID list to one of a studyID
	list. Instead of looking for exact matches to sampleIDs, matches will be to any samples beginning
	with the listed studyIDs.
	
	If using the -i studyID option, adding the -c controls option will also capture any controls using
	the regex '/00.+\/{0}\.paired\.for\.fastaEOL'


	The output file is:

	<generated sample id> \\t <paired.for.fasta path> \\n

";

if(!(
	defined($opt_r) &&
	defined($opt_s) && 
	defined($opt_o))){
	die $usage;
}


my $output_fname=$opt_o;
my $run_list=$opt_r;
my $sample_list=$opt_s;
my $studyID;

print STDERR "\n";

print STDERR "Run List: $run_list\n";
print STDERR "Sample List: $sample_list\n";
print STDERR "Output Filename: $output_fname\n";

###############################################################################
my @runlist;
my @sampleIDlist;
my @filelist;
my @fastalist;
my @fullfastalist;
my @matchedlist;

#Creates a list of runs from the input run list text file

open(R, $opt_r) or die("no file named: $opt_r!\n");

while(<R>) {
	chomp;
	push(@runlist, $_);
}
close(R);

open(S, $opt_s) or die("no file named: $opt_s!\n");
while(<S>) {
	chomp;
	push(@sampleIDlist, $_);
}
close(S);


my $cwd = cwd();

#This searches each run directory and makes a list of all files under that run_path.
foreach my $runID(@runlist){
        @filelist=split "\n", `find $runID`;
	foreach my $filereturn(@filelist){
		push @fullfastalist, $filereturn;
	}
}


#Compares the sampleID list to the fullfastalist and creates a smaller list with matches
#If -i isnt set, it only matches exactly to the name of the sampleID.paired.for.fasta.
#if -i is set, will match based on provided studyID(s). If -c is set, will include control samples.
foreach my $sname(@sampleIDlist){
	if($opt_i){
	$sname=join "", $sname, ".+";
	}
	foreach my $fname(@fullfastalist){
		if($fname =~/\/$sname\/{0}\.paired\.for\.fasta$/){
			push @fastalist, $fname;
		}elsif($opt_c && $opt_i && $fname =~/\/00.+\/{0}\.paired\.for\.fasta$/){
                        push @fastalist, $fname;
	
		}
	}
}


print STDERR "Found FASTA files: \n";
my %map;
foreach my $fpath(@fastalist){
        print STDERR "$fpath\n";
        my ($name, $path)=fileparse($fpath);
        @{$map{$fpath}}=split /\./, $name;
}


#compare values from the sampleID list with found paired.for.fasta sample names
my %sampleIDHash;

if(not $opt_i){
	foreach my $string (keys %map){
		my $jstring = join ".", @{$map{$string}};
		$jstring =~ s/\.paired\.for\.fasta//;
		$sampleIDHash{$jstring}=1;
	}
	#looking for all non-matched sampleIDs from the original list
	print STDERR "Did not find fasta for:\n";
	foreach my $sampleID(@sampleIDlist){
		chomp $sampleID;
		if(not exists($sampleIDHash{$sampleID})){
			print STDERR "$sampleID\n";
		}
	}
}


# If any sample id's are redundant, try to make it unique
print STDERR "Checking Sample IDs for uniqueness...\n";
my %uniq_hash;
my %cnts_hash;

# Count duplicates
foreach my $fpath(keys %map){
        my $samp_id = join ".", @{$map{$fpath}};
        if(defined($uniq_hash{$samp_id})){
                $uniq_hash{$samp_id}++;
                $cnts_hash{$samp_id}++;
                print STDERR "Duplicated Sample ID found: $samp_id\n";
        }else{
                $uniq_hash{$samp_id}=1;
                $cnts_hash{$samp_id}=1;
        }
}

my %sampid_to_path_hash;
my %samp_to_uniqsamp_hash;
# Append ID with r#
foreach my $fpath(keys %map){
        my $samp_id = join ".", @{$map{$fpath}};
        my $uniq_samp_id=$samp_id;
        if($cnts_hash{$samp_id}>1){
                $uniq_samp_id="$samp_id.r$uniq_hash{$samp_id}";
                $uniq_hash{$samp_id}--;
        }
        $sampid_to_path_hash{$uniq_samp_id}=$fpath;
        $samp_to_uniqsamp_hash{$uniq_samp_id}=$samp_id;
}


###############################################################################

open(OUT_FH, ">$output_fname") || die "Could not open $output_fname\n";

foreach my $samp_id(sort keys %sampid_to_path_hash){
	my $samp_id_cut = $samp_id =~ s/\.paired\.for\.fasta//r;
        print OUT_FH "$samp_id_cut\t$sampid_to_path_hash{$samp_id}\n";
}

close(OUT_FH);

#-----------------------------------------------------------------------------

my $collapse_rep_tsv="$output_fname.clps.tsv";
open(OUT_FH, ">$collapse_rep_tsv") || die "Could not open $collapse_rep_tsv\n";

print OUT_FH "ReplicateID\tSampleID\n";
foreach my $uniq_samp_id(sort keys %samp_to_uniqsamp_hash){
	my $repl_samp_id_cut = $uniq_samp_id =~ s/\.paired\.for\.fasta//r;
	my $samp_id = $samp_to_uniqsamp_hash{$uniq_samp_id} =~ s/\.paired\.for\.fasta//r;
        print OUT_FH "$repl_samp_id_cut\t$samp_id\n";
}

close(OUT_FH);


#------------------------------------------------------------------------------

my $unmatched_sample_tsv="$output_fname.unmatched.tsv";
open(OUT_FH, ">$unmatched_sample_tsv") || die "Could not open $unmatched_sample_tsv\n";

print OUT_FH "UmatchedID\n";

if(not $opt_i){
        foreach my $sampleID(@sampleIDlist){
                chomp $sampleID;
                if(not exists($sampleIDHash{$sampleID})){
                        print OUT_FH "$sampleID\n";
                }
        }
}

close(OUT_FH);


###############################################################################

print STDERR "done.\n";

