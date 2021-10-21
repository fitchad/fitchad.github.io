#!/usr/bin/env perl

#To Do:
#1. look for a matching set of R1 and R2, report if not a complete.
#2. Use the matched list to create a tar file with all the matched files in it
#3. Since i will be dumping all files into the same directory, will
#have to append the .r1 extension before the .fastq.gz. Also, will have to rename files on the 
#duplicated list prior to attempting to add to the tar.gz file.

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
	-o <output name root>
	-i [interpret sampleID list as a list of studyIDs]
	-c [include controls in output if using studyID list option]
	

	This script will look through all the fastq.gz files
	in the specified path(s), and generate a sampleID to fastq.gz file
	path for the listed sampleIDs. 

	The run list file -r should be the full paths of where you want to
	look for the fastq.gz files, for example:
	/mnt/cmmnas02/SequencingRuns/20180934_efef_dfdfe__RN-0000/Run

	The output file is:

	<generated sample id> \\t <fastq.gz file path> \\n

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

foreach my $sname(@sampleIDlist){
#	$sname=join "", $sname, ".+";
	foreach my $fname(@fullfastalist){
		if($fname =~/\/$sname\/{0}.+\_R[1|2]\_001\.fastq\.gz$/){
			push @fastalist, $fname;
		}
	}
}

print STDERR "Found FASTQ files: \n";
my %map;
foreach my $fpath(@fastalist){
#        print STDERR "$fpath\n";
        my ($name, $path)=fileparse($fpath);
        @{$map{$fpath}}=$name;
}


#compare values from the sampleID list with found fastq.gz sample names.
#Works now, however, only looks to see if the sampleID is in the hash, not if 
#there is a pair of reads corresponding to it. 

my %sampleIDHash;

if(not $opt_i){
	foreach my $string (keys %map){
		my $jstring = join ".", @{$map{$string}};
		$jstring =~ s/\_[[:alnum:]]+\_[[:alnum:]]+\_R[1|2]\_001\.fastq\.gz//;
		$sampleIDHash{$jstring}=1;
	}
	#looking for all non-matched sampleIDs from the original list
#	print STDERR "Did not find fasta for:\n";
	foreach my $sampleID(@sampleIDlist){
		chomp $sampleID;
		if(not exists($sampleIDHash{$sampleID})){
#			print STDERR "$sampleID\n";
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
 #               print STDERR "Duplicated Sample ID found: $samp_id\n";
        }else{
                $uniq_hash{$samp_id}=1;
                $cnts_hash{$samp_id}=1;
        }
}

my %sampid_to_path_hash;
my %samp_to_uniqsamp_hash;
# Append ID with r#
#likely need to adjust this. since i will be dumping all files into the same directory, will
#have to append the .r1 extension before the .fastq.gz. Also, will have to rename files on the 
#duplicated list prior to attempting to add to the tar.gz file. 
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
	my $samp_id_cut = $samp_id =~ s/\_[[:alnum:]]+\_[[:alnum:]]+\_R[1|2]\_001\.fastq\.gz//r;
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

