#!/usr/bin/env perl

#To Do:
#1.report if non matching pairs of R1 / R2.
	# Done for R1...harder to do for R2 as everything is based off of R1. 
	#. could simply repeat proceedure for R2 first and output results (but not record results for future use)
#2. cleanup / remove unnecessary code

###############################################################################

use strict;
use warnings;
use Getopt::Std;
use FileHandle;
use File::Basename;
use File::Find;
use vars qw($opt_r $opt_s $opt_o $opt_p);
use Cwd;
use Archive::Tar;

getopts("r:s:o:p");
my $usage = "usage: 

$0 

	-r <run path list>
	-s <sampleID list>
	-o <output name root>
	[-p <prompt before writing Tarfile>]
	

	This script will look through all the fastq.gz files
	in the specified path(s), match them to the supplied sampleID list,
	and create a tar.gz file containing the requested files. 

	The run list file -r should be the full paths of where you want to
	look for the fastq.gz files, for example:
	/mnt/cmmnas02/SequencingRuns/20180934_efef_dfdfe__RN-0000/Run

	The script now matches the directory name for R1/R2 file pairs so these
	files should be in the same subdirectory. 

	The output file is a tar.gz file containing all matched R1 and R2 fastq.gz files.
	All matched files will be dumped into a single directory as requested by SRA. 
	Duplicated filenames will be appended with an .r# to make them unique.

	If the -p prompt option is used, you will be asked if you would like to continue
	to the tarfile creation step (ie, do you want to write the tarfile based
	on the missing/matched samples). Default is to not write the tarfile unless Y is entered
	at the prompt. If input other than 'Y' is entered, the script will write out the log files and exit. 


	The following logfiles are created:
	1. sampleID <\t> R1_file <\t> R2_file
	2. filename <\t> original directory of file 
	3. unmatched sampleID file

";

if(!(
	defined($opt_r) &&
	defined($opt_s) && 
	defined($opt_o))){
	die $usage;
}


my $run_list=$opt_r;
my $sample_list=$opt_s;
my $output_fname=$opt_o;
my $studyID;

my $write_file="Y";

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
my $missingsamplecount=0;

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

#should update to limit to just fastq.gz files.

foreach my $runID(@runlist){
        @filelist=split "\n", `find $runID ! -type d`;
	foreach my $filereturn(@filelist){
		push @fullfastalist, $filereturn;
	}
}


#Compares the sampleID list to the fullfastalist and creates a smaller list that contains 
#only pairs of R1 and R2 files. Should cover all iterations of naming (ie, matching is permissive between
#the sampleID and "_R1_001.fastq.gz". 



foreach my $sname(@sampleIDlist){

	foreach my $fname(@fullfastalist){
		my($filename, $directory) = fileparse($fname);
		if($filename =~/($sname.+)\_R1\_001\.fastq\.gz$/){
			my $tempname=$1;
			my $bool=1;
			foreach my $fname2(@fullfastalist){
				my($filename2, $directory2) = fileparse($fname2);
#added 5/8/23. insures you are looking in the same directory for a matching R1/R2 pair
					if($directory eq $directory2){

						if($filename2 =~/$tempname\_R2\_001\.fastq\.gz$/){
				                       push @fastalist, $fname;
        			       	               push @fastalist, $fname2;
							$bool=0;

						}
					}

				}
		if($bool){
			print STDERR "found unmatched R1 file $filename\n";
			}

		}
	}
}

#makes a map of the path as key, filename as value
# key includes the full filepath so as not to overwrite R1 with R2 later. 

print STDERR "Found matched FASTQ file pairs: \n";
my %map;
foreach my $fpath(@fastalist){
        my ($name, $path)=fileparse($fpath);
        @{$map{$fpath}}=$name;
#	@{$map{$path}}=$name; ##error due to strict, can use string as array reference
	print STDERR "$path\t$name\n";
}



my %sampleIDHash;

#parses out the filename from the filepath, substitues down to just the sampleID
#and adds that value to hash.

foreach my $fpath (keys %map){
	my ($name, $path)=fileparse($fpath);
#	my $filename= join "", @{$map{$my_path}};
	$name=~ s/\_[[:alnum:]]+\_[[:alnum:]]+\_R[1|2]\_001\.fastq\.gz//;
#	print STDERR "subbed down to name: $name\n";
	$sampleIDHash{$name}=1;
}



#this is only exact matching to original list

foreach my $sampleID(@sampleIDlist){

	if(exists($sampleIDHash{$sampleID})){
#		print STDERR" Found: $sampleID\n";
	}
	else{
		print STDERR "Didn't find exact match to $sampleID\n";
		print STDERR "***There could be an iteration of this name so please check outputs***\n";
		$missingsamplecount=$missingsamplecount+1
	}

}



# If any sample id's are redundant, try to make it unique
print STDERR "Checking Sample IDs for uniqueness...\n";
my %uniq_hash;
my %cnts_hash;

# Count duplicates
foreach my $sample_key(keys %map){
        my $samp_id = join "", @{$map{$sample_key}};
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

#can clean this up. remove second if statement and just grab needed information for rename.  
#sorting keys first seems to clean up the mismatched r1/r2 problem. will need more testing. 

foreach my $fpath(sort keys %map){
        my $samp_id = join "", @{$map{$fpath}};
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

my $sampleID_path_map_tsv="$output_fname.sampleID_orig_fileloc.tsv";

open(OUT_FH, ">$sampleID_path_map_tsv") || die "Could not open $sampleID_path_map_tsv\n";

print OUT_FH "SampleID\tOriginalPath\n";
foreach my $samp_id(sort keys %sampid_to_path_hash){
	my $samp_id_cut = $samp_id =~ s/\_[[:alnum:]]+\_[[:alnum:]]+\_R[1|2]\_001.*\.fastq\.gz//r;
        print OUT_FH "$samp_id_cut\t$sampid_to_path_hash{$samp_id}\n";
}

close(OUT_FH);

#-----------------------------------------------------------------------------


my $map_tsv="$output_fname.map.tsv";
open(OUT_FH, ">$map_tsv") || die "Could not open $map_tsv\n";
foreach my $uniq_samp_id(sort keys %samp_to_uniqsamp_hash){

	if($uniq_samp_id =~/(.+)(\_R1\_001.*)\.fastq\.gz/){
		my $tempname=$1;
		my $repname=$2;
		foreach my $samp_id_2(keys %samp_to_uniqsamp_hash){
			my $repnameupd = $repname =~ s/\_R1\_001/\_R2\_001/r;
			if($samp_id_2 =~/$tempname$repnameupd\.fastq\.gz/){

				print OUT_FH "$tempname\t$uniq_samp_id\t$samp_id_2\n";
			}
		}

	}
}

close(OUT_FH);

#-----------------------------------------------------------------------------


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



#------------------------------------------------------------------------------

#add prompt to create tarfile or skip due to missing samples


if($opt_p){
	print STDERR "There are: $missingsamplecount samples without exact match sampleID - fastq file pairs\n";
	print STDERR "Do you wish to write the Tarfile (Y or N)? ";
	$write_file = <STDIN>;	
	chomp $write_file;
	if($write_file ne "Y"){
		print STDERR "Writing Logs and Exiting...\n";
	}
}

if ($write_file eq "Y"){

	print STDERR "Writing Tarfile...\n";

	my $tarfile=Archive::Tar->new; 

	foreach my $file(keys %map){
	#	print STDERR "@{$map{$file}}";
	#	my $fpath_file = join("", "$file@{$map{$file}}" ); 
		$tarfile->add_files("$file");
	}

	my @filenames=$tarfile->get_files;


	foreach my $samp_id(sort keys %sampid_to_path_hash){
#		$sampid_to_path_hash{$samp_id} =~ s/.//; #this removes the leading "/" from the name in the map as it is not present in the file.
		$tarfile->rename($sampid_to_path_hash{$samp_id}, $samp_id);
	}


	$tarfile->write("$output_fname.tgz", COMPRESS_GZIP);
}


###############################################################################

print STDERR "done.\n";

