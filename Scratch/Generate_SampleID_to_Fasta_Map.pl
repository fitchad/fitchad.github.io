#!/usr/bin/env perl



###############################################################################

use strict;
use warnings;
use Getopt::Std;
use FileHandle;
use File::Basename;
use File::Find;
use vars qw($opt_r $opt_s $opt_q $opt_p $opt_o);
use Cwd;
use Data::Dumper qw(Dumper);


getopts("r:s:q:p:o:");
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

	The run list file -r should be the full paths of where you want to
	look for the paired.for.fasta files, for example:
	/mnt/cmmnas02/SequencingRuns/20180934_efef_dfdfe__RN-0000/QC/QV_30/MergeMates

	The sampleID list should be exact matches to sampleIDs. Options are being
	added to do fuzzy matches or to look for all the samples from a certain study(ies)

	the -q and -p are currently inactive as I decide best course of action. 


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
$target_path="/home/acf/TEST";
#$target_path='/mnt/cmmnas02/SequencingRuns';
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

my @filelist;
my @fastalist;
my @runlist;
my @fullfastalist;
my @sampleIDlist;
my @matchedlist;

#Creates a list of runs from the input run list text file

open(F, $opt_r) or die("no file named: $opt_r!\n");

while(<F>) {
	chomp;
	push(@runlist, $_);
}
close(F);

open(S, $opt_s) or die("no file named: $opt_s!\n");
while(<S>) {
	chomp;
	push(@sampleIDlist, $_);
}
close(S);


my $cwd = cwd();

#This searches each run and makes a list of all files under that run_path.
foreach my $runID(@runlist){
#	my $run_path=$target_path . '/' . $runID . '/' . "QC" . '/' . "QV_" . $qv_value . '/' . "MergeMates";
#	@filelist=split "\n", `find $run_path`;
        @filelist=split "\n", `find $runID`;
	foreach my $filereturn(@filelist){
		push @fullfastalist, $filereturn;
	}
}


#This compares the samples list to the fullfastalist and creates a smaller list with matches
#Only matches exactly to the name of the sampleID.paired.for.fasta
foreach my $sname(@sampleIDlist){
	foreach my $fname(@fullfastalist){
		if($fname =~/$sname\.paired\.for\.fasta$/){
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
#	print STDERR join ".", @{$map{$fpath}};
}

print Dumper \%map;


#creating an array of the sampleIDs
my @tempArray;
foreach my $string (keys %map){
	my $jstring = join ".", @{$map{$string}};
	$jstring =~ s/\.paired\.for\.fasta//;
	push @tempArray, $jstring;
}
#looking for all non-matched sampleIDs from the original list and for now printing but will push to file.
foreach my $sampleID(@sampleIDlist){
	chomp $sampleID;
	print STDERR $sampleID;
	if ( not /$sampleID/ ~~ @tempArray){
		print STDERR "Did not find fasta for: $sampleID\n";	
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
        print OUT_FH "$samp_id\t$sampid_to_path_hash{$samp_id}\n";
}

close(OUT_FH);

#-----------------------------------------------------------------------------

my $collapse_rep_tsv="$output_fname.clps.tsv";
open(OUT_FH, ">$collapse_rep_tsv") || die "Could not open $collapse_rep_tsv\n";

print OUT_FH "ReplicateID\tSampleID\n";
foreach my $uniq_samp_id(sort keys %samp_to_uniqsamp_hash){
        print OUT_FH "$uniq_samp_id\t$samp_to_uniqsamp_hash{$uniq_samp_id}\n";
}

close(OUT_FH);

###############################################################################

print STDERR "done.\n";

