#!/usr/bin/env perl

#To Do:
#1. update so that controls are only searched for in directories that have a studyID match
#2. add the ability to change the file extension?


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
	-o <output sample id to fastq mapping file>
	-i [interpret sampleID list as a list of studyIDs]
	-c [include controls in output if using studyID list option]
	

	This script will look through all the paired FASTQ files (_R1_001.fastq.gz and _R2_001.fastq.gz)
	in the specified path(s), and generate a sampleID to paired FASTQ file
	path for the listed sampleIDs. 

	The run list file -r should be the full paths of where you want to
	look for the FASTQ files (to avoid unintentional matches), although the script will look 
	through sub-directories of the Run directory. Example directory:
	/mnt/cmmnas02/SequencingRuns/20180934_efef_dfdfe__RN-0000/Run

	The SampleID list should be exact matches to sampleIDs, to prevent unintentional matches.
	Fastq files typically have dashes (-) between fields, not periods (.), due to MiSeq specs,
	so the SampleID list should be the same (for eg "0290-Sub5-Visit1-ST")
	SampleID list should not include "_S1_L001_R[12]_001.fastq.gz" text. 

	The -i studyID option changes the interpretation of the sampleID list to one of a studyID
	list. Instead of looking for exact matches to sampleIDs, matches will be to any samples beginning
	with the listed studyIDs.
	
	If using the -i studyID option, adding the -c controls option will also capture any controls in the runs
	using the regex '/00.+_S*_L001_R[12]_001\.fastq\.gz\$'

	The output file is:

	<sampleID> \\t <R1_fastq_path> \\t <R2_fastq_path> \\n

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
my @fastqlist;
my @fullfastqlist;
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

#This searches each run directory and makes a list of all FASTQ files under that run_path.
foreach my $runID(@runlist){
        @filelist=split "\n", `find $runID -name "*_S*_L001_R[12]_001.fastq.gz"`;
	foreach my $filereturn(@filelist){
		push @fullfastqlist, $filereturn;
	}
}


#Compares the sampleID list to the fullfastqlist and creates a smaller list with matches
#If -i isnt set, it only matches exactly to the name of the sampleID_S*_L001_R1_001.fastq.gz.
#if -i is set, will match based on provided studyID(s). If -c is set, will include control samples.
foreach my $sname(@sampleIDlist){
	my $search_pattern;
	if($opt_i){
		$search_pattern = qr/\/${sname}.+_S\d+_L\d+_R[12]_001\.fastq\.gz$/;
	} else {
		$search_pattern = qr/\/${sname}_S\d+_L\d+_R[12]_001\.fastq\.gz$/;
	}
	
	foreach my $fname(@fullfastqlist){
		if($fname =~ $search_pattern){
			push @fastqlist, $fname;
		}elsif($opt_c && $opt_i && $fname =~/\/00.+_S\d+_L\d+_R[12]_001\.fastq\.gz$/){
                        push @fastqlist, $fname;
		}
	}
}


print STDERR "Found FASTQ files: \n";
my %r1_files;
my %r2_files;
my %sample_ids;

# Separate R1 and R2 files and extract sample IDs
foreach my $fpath(@fastqlist){
        print STDERR "$fpath\n";
        my ($name, $path)=fileparse($fpath);
        
        # Extract sample ID by removing _S*_L001_R[12]_001.fastq.gz
        my $sample_id = $name;
        $sample_id =~ s/_S\d+_L\d+_R[12]_001\.fastq\.gz$//;
        
        $sample_ids{$sample_id} = 1;
        
        if($name =~ /_R1_001\.fastq\.gz$/){
            $r1_files{$sample_id} = $fpath;
        } elsif($name =~ /_R2_001\.fastq\.gz$/){
            $r2_files{$sample_id} = $fpath;
        }
}


#compare values from the sampleID list with found FASTQ sample names
my %sampleIDHash;

if(not $opt_i){
	foreach my $sample_id (keys %sample_ids){
		$sampleIDHash{$sample_id}=1;
	}
	#looking for all non-matched sampleIDs from the original list
	print STDERR "Did not find FASTQ files for:\n";
	foreach my $sampleID(@sampleIDlist){
		chomp $sampleID;
		if(not exists($sampleIDHash{$sampleID})){
			print STDERR "$sampleID\n";
		}
	}
}


# Check for paired files (both R1 and R2 present)
print STDERR "Checking for paired FASTQ files...\n";
my %paired_samples;
my @unpaired_samples;

foreach my $sample_id (keys %sample_ids){
    if(exists($r1_files{$sample_id}) && exists($r2_files{$sample_id})){
        $paired_samples{$sample_id} = 1;
    } else {
        push @unpaired_samples, $sample_id;
        print STDERR "WARNING: Unpaired sample found: $sample_id\n";
        if(!exists($r1_files{$sample_id})){
            print STDERR "  Missing R1 file\n";
        }
        if(!exists($r2_files{$sample_id})){
            print STDERR "  Missing R2 file\n";
        }
    }
}


###############################################################################

open(OUT_FH, ">$output_fname") || die "Could not open $output_fname\n";

foreach my $sample_id(sort keys %paired_samples){
    if(exists($r1_files{$sample_id}) && exists($r2_files{$sample_id})){
        print OUT_FH "$sample_id\t$r1_files{$sample_id}\t$r2_files{$sample_id}\n";
    }
}

close(OUT_FH);

#-----------------------------------------------------------------------------

# Create a file listing unpaired samples
my $unpaired_sample_tsv="$output_fname.unpaired.tsv";
open(OUT_FH, ">$unpaired_sample_tsv") || die "Could not open $unpaired_sample_tsv\n";

print OUT_FH "UnpairedID\tR1_Present\tR2_Present\n";
foreach my $sample_id(@unpaired_samples){
    my $r1_present = exists($r1_files{$sample_id}) ? "YES" : "NO";
    my $r2_present = exists($r2_files{$sample_id}) ? "YES" : "NO";
    print OUT_FH "$sample_id\t$r1_present\t$r2_present\n";
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
