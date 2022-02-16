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
use vars qw($opt_r $opt_s $opt_o);
use Cwd;
use Archive::Tar;

getopts("r:s:o");
my $usage = "usage: 

$0 

	-r <run path list>
	-s <sampleID list>
	-o <output name root>
	

	This script will look through all the fastq.gz files
	in the specified path(s), match them to the supplied sampleID list,
	and create a tar.gz file containing the requested files. 

	The run list file -r should be the full paths of where you want to
	look for the fastq.gz files, for example:
	/mnt/cmmnas02/SequencingRuns/20180934_efef_dfdfe__RN-0000/Run

	The output file is a tar.gz file containing all matched R1 and R2 fastq.gz files.
	All matched files will be dumped into a single directory as requested by SRA. 

	

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

#Creates a list of sampleIDs from the input sampleID text list file

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


#Compares the sampleID list to the fullfastalist and creates a smaller list that contains 
#only pairs of R1 and R2 files. Should cover all iterations of naming (ie, matching is permissive between
#the sampleID and "_R1_001.fastq.gz". 

#corrected - put path capture and reuse in match. should be good now. 



foreach my $sname(@sampleIDlist){
	foreach my $fname(@fullfastalist){
               if($fname =~/(^\/\S.+)(\/$sname\/{0}.+)\_R1\_001\.fastq\.gz$/){
			my $pathname=$1;
			my $tempname=$2;
			foreach my $fname2(@fullfastalist){
				if($fname2 =~/$pathname$tempname\_R2\_001\.fastq\.gz$/){
				push @fastalist, $fname;
				push @fastalist, $fname2;
#				print STDERR "$fname\n$fname2\n";

				}
			}
               }

	}
}


#this is not printing out correct information. duplicates and wrong matches. 
print STDERR "Found FASTQ files: \n";
my %map;
foreach my $fpath(@fastalist){
        my ($name, $path)=fileparse($fpath);
        @{$map{$fpath}}=$name;
	print STDERR "$path\t$name\n";
}

#compare values from the sampleID list with found fastq.gz sample names.
#Missing sampleIDs are printed to STDERR

my %sampleIDHash;

foreach my $string (keys %map){
	my $jstring = join ".", @{$map{$string}};
	$jstring =~ s/\_[[:alnum:]]+\_[[:alnum:]]+\_R[1|2]\_001\.fastq\.gz//;
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
#will have to rename files on the 
#duplicated list prior to attempting to add to the tar.gz file. 

#can clean this up. remove second if statement and just grab needed information for rename.  

foreach my $fpath(keys %map){
        my $samp_id = join ".", @{$map{$fpath}};
	my $uniq_samp_id=$samp_id;
        if($cnts_hash{$samp_id}>1){
		if($samp_id =~ /(.+\_R[1|2]\_001)(\.fastq\.gz)/){
			my $tname1=$1;
			my $tname2=$2;
			$uniq_samp_id="$tname1.r$uniq_hash{$samp_id}$tname2";
#                $uniq_samp_id="$samp_id.r$uniq_hash{$samp_id}";
                	$uniq_hash{$samp_id}--;
		} 
       }
        $sampid_to_path_hash{$uniq_samp_id}=$fpath;
	
        $samp_to_uniqsamp_hash{$uniq_samp_id}=$samp_id;
}




###############################################################################

open(OUT_FH, ">$output_fname") || die "Could not open $output_fname\n";

foreach my $samp_id(sort keys %sampid_to_path_hash){
	my $samp_id_cut = $samp_id =~ s/\_[[:alnum:]]+\_[[:alnum:]]+\_R[1|2]\_001*\.fastq\.gz//r;
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

foreach my $sampleID(@sampleIDlist){
        chomp $sampleID;
        if(not exists($sampleIDHash{$sampleID})){
                print OUT_FH "$sampleID\n";
                }
}


close(OUT_FH);


#-------------------------------------------------------------------------------

#add prompt to create tarfile or skip due to missing samples

my $tarfile=Archive::Tar->new; 

foreach my $file(keys %map){
	$tarfile->add_files("$file");
}

my @filenames=$tarfile->get_files;


foreach my $samp_id(sort keys %sampid_to_path_hash){
	$sampid_to_path_hash{$samp_id} =~ s/.//; #this removes the leading "/" from the name in the map as it is not present in the file.
	$tarfile->rename($sampid_to_path_hash{$samp_id}, $samp_id);
}


$tarfile->write("$output_fname.tgz", COMPRESS_GZIP);



###############################################################################

print STDERR "done.\n";

