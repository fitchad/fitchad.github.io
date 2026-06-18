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

###############################################################################
# Subroutine: check if a fastq.gz file is empty (has no reads)
# Gunzips to a temp file and counts lines. A valid fastq has 4 lines per read.
# Returns 1 if empty, 0 if not.
sub is_empty_fastq {
	my ($fpath) = @_;
	return 0 if -s $fpath > 2048;  # skip check if file > 2kb, can't be empty
	my $tmpfile = "/tmp/check_fastq_$$.fastq";
	my $ret = system("gunzip -c '$fpath' > '$tmpfile' 2>/dev/null");
	if ($ret != 0) {
		unlink $tmpfile;
		print STDERR "Warning: gunzip failed on $fpath — skipping empty check, treating as non-empty\n";
		return 0;
	}
	open(my $fh, "<", $tmpfile) or return 1;
	my $linecount = 0;
	while(<$fh>){
		$linecount++;
		last if $linecount >= 4;  # only need to find one read
	}
	close($fh);
	unlink $tmpfile;
	# a valid fastq has at least 4 lines (one read); fewer = empty
	return ($linecount < 4) ? 1 : 0;
}
###############################################################################
# Subroutine: derive a short LibraryID from a fastq filepath.
# Format: <RunID>_<SNN>
#   RunID: RN_XXXX extracted from the run directory name, or the leading
#          YYYYMMDD date if no RN_XXXX is present.
#   SNN:   the _S<digits>_ field from the fastq filename (unique within a run).
sub get_library_id {
	my ($fpath) = @_;

	# Extract SNN from filename (e.g. SampleName_S12_L001_R1_001.fastq.gz -> S12)
	my ($fname, $dir) = fileparse($fpath);
	my $snn = "SUNK";  # fallback if pattern not found
	if ($fname =~ /_S(\d+)_/) {
		$snn = "S$1";
	}

	# Extract run ID from the directory path
	# Preference 1: RN_XXXX (with optional trailing _digits)
	my $run_id = "";
	if ($fpath =~ /(RN[_-]\d+)/i) {
		$run_id = uc($1);
		$run_id =~ s/-/_/;  # normalize RN-XXXX to RN_XXXX
	}
	# Preference 2: fall back to leading YYYYMMDD date in the run directory name
	elsif ($fpath =~ /\/(\d{8})_/) {
		$run_id = $1;
	}
	# Preference 3: fall back to the full run directory name — guaranteed unique,
	# avoids LibraryID collisions when multiple directories lack RN_ or date.
	else {
		# Extract just the run directory component (one level above /Run/)
		if ($fpath =~ /\/([^\/]+)\/Run\//i) {
			$run_id = $1;
		} elsif ($fpath =~ /\/([^\/]+)\/[^\/]+\.fastq\.gz$/) {
			$run_id = $1;
		} else {
			$run_id = $dir;  # last resort: use whatever directory we parsed
		}
		$run_id =~ s/\s+/_/g;  # sanitize any spaces
		print STDERR "Warning: no RN_ or date found in path, using directory name as RunID: $run_id\n";
	}

	return "${run_id}_${snn}";
}
###############################################################################

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
my %pair_map;
my $missingsamplecount=0;
my $write_file="Y";

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

# Use File::Find to locate all fastq.gz files — avoids shell metacharacter risks
# from backtick find, and limits to only the files we care about.
# Build a hash: $dir_file_hash{$run_root}{$filename} = full_path
# The key is the canonical run root (path up to and including /Run/) rather than
# the immediate parent directory, so R1/R2 matching is strictly confined to the
# same SequencingRun/Run directory and cannot match across runs.

my %dir_file_hash;

# Helper: extract the run root (up to and including /Run/) from a full path.
# Falls back to the immediate parent directory if no /Run/ component is found.
sub get_run_root {
	my ($fpath) = @_;
	if ($fpath =~ m{^(.+/Run)/}i) {
		return $1;
	}
	my (undef, $dir) = fileparse($fpath);
	return $dir;
}

foreach my $runID (@runlist) {
	find(sub {
		return unless /\.fastq\.gz$/;
		my $fpath = $File::Find::name;
		my ($fname, $dir) = fileparse($fpath);
		my $run_root = get_run_root($fpath);
		$dir_file_hash{$run_root}{$fname} = $fpath;
		push @fullfastalist, $fpath;
	}, $runID);
}

# Compares the sampleID list to the fullfastalist and creates a smaller list that
# contains only pairs of R1 and R2 files. Uses hash lookup for R2 match (O(1)).
# Also checks for unmatched R2 files.

my %seen_r2;  # track which R2 files have been matched

foreach my $sname (@sampleIDlist) {
	foreach my $fname (@fullfastalist) {
		my ($filename, $directory) = fileparse($fname);
		if ($filename =~ /($sname.+)_R1_001\.fastq\.gz$/) {
			my $tempname = $1;
			my $r2name   = "${tempname}_R2_001.fastq.gz";
			# O(1) lookup: check same run root directory for matching R2
			my $run_root = get_run_root($fname);
			if (exists $dir_file_hash{$run_root}{$r2name}) {
				my $r2path = $dir_file_hash{$run_root}{$r2name};
				push @fastalist, $fname;
				push @fastalist, $r2path;
				$seen_r2{$r2path} = 1;
				# record each file's partner for pair-aware empty exclusion
				$pair_map{$fname}  = $r2path;
				$pair_map{$r2path} = $fname;
			} else {
				print STDERR "found unmatched R1 file (no R2): $filename\n";
			}
		}
	}
}

# Check for R2 files that have no matching R1
foreach my $fname (@fullfastalist) {
	my ($filename, $directory) = fileparse($fname);
	if ($filename =~ /_R2_001\.fastq\.gz$/ && !exists $seen_r2{$fname}) {
		print STDERR "found unmatched R2 file (no R1): $filename\n";
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
	$name=~ s/\_[[:alnum:]]+\_[[:alnum:]]+\_R[12]\_001\.fastq\.gz//;
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
my %path_to_uniq;   # reverse of sampid_to_path_hash: orig_path -> unique_name

# Append ID with r#

#can clean this up. remove second if statement and just grab needed information for rename.  
#sorting keys first seems to clean up the mismatched r1/r2 problem. will need more testing. 

foreach my $fpath(sort keys %map){
        my $samp_id = join "", @{$map{$fpath}};
	my $uniq_samp_id=$samp_id;
        if($cnts_hash{$samp_id}>1){
		if($samp_id =~ /(.+\_R[12]\_001)(\.fastq\.gz)/){
			my $tname1=$1;
			my $tname2=$2;
			$uniq_samp_id="$tname1.r$uniq_hash{$samp_id}$tname2";
                	$uniq_hash{$samp_id}--;
		} 
       }
        $sampid_to_path_hash{$uniq_samp_id}=$fpath;
	$path_to_uniq{$fpath}=$uniq_samp_id;
        $samp_to_uniqsamp_hash{$uniq_samp_id}=$samp_id;
}




###############################################################################

my $empty_files_tsv="$output_fname.empty_fastq.tsv";
my $sampleID_path_map_tsv="$output_fname.sampleID_orig_fileloc.tsv";

#------------------------------------------------------------------------------
# Check for empty fastq.gz files and log them — must happen before map files
# are written so empty files can be excluded from all outputs.

my %empty_files;

print STDERR "Checking for empty fastq.gz files...\n";

open(my $empty_fh, ">", $empty_files_tsv) || die "Could not open $empty_files_tsv\n";
print $empty_fh "EmptyFile\tOriginalPath\tNote\n";

foreach my $fpath (keys %map) {
	my ($name, $path) = fileparse($fpath);
	if (is_empty_fastq($fpath)) {
		print STDERR "Empty fastq found (will be excluded from all outputs): $name\n";
		$empty_files{$fpath} = 1;
		print $empty_fh "$name\t$path\tempty\n";
	}
}

# Propagate: if one file of a pair is empty, exclude its partner too
foreach my $fpath (keys %empty_files) {
	my $partner = $pair_map{$fpath};
	if (defined $partner && !$empty_files{$partner}) {
		my ($pname, $ppath) = fileparse($partner);
		print STDERR "Excluding partner of empty file (will be excluded from all outputs): $pname\n";
		$empty_files{$partner} = 1;
		print $empty_fh "$pname\t$ppath\t(partner of empty file)\n";
	}
}
close($empty_fh);

my $empty_count = scalar keys %empty_files;
if ($empty_count > 0) {
	print STDERR "Total empty fastq.gz files excluded: $empty_count\n";
	print STDERR "Empty file log written to: $empty_files_tsv\n";
} else {
	print STDERR "No empty fastq.gz files found.\n";
}

#------------------------------------------------------------------------------

# Build the full list of map rows first so we know the total count
# and can decide whether chunking is needed.
# Each entry is a hashref with all fields needed for both map file and tar.
# Use %pair_map for direct R2 lookup — avoids the fragile inner loop.
my @map_rows;
my $debug_r1_count = 0;
my $debug_skip_r1_filter = 0;
my $debug_skip_no_orig = 0;
my $debug_skip_empty = 0;
my $debug_skip_no_r2_pair = 0;
my $debug_skip_no_r2_uniq = 0;

foreach my $uniq_samp_id (sort keys %samp_to_uniqsamp_hash){

	# only process R1 entries — R2 is looked up via pair_map
	unless ($uniq_samp_id =~ /_R1_001.*\.fastq\.gz$/) {
		$debug_skip_r1_filter++;
		next;
	}
	$debug_r1_count++;

	my $r1_orig_path = $sampid_to_path_hash{$uniq_samp_id};
	unless (defined $r1_orig_path) {
		print STDERR "DEBUG: no orig path for uniq_samp_id=$uniq_samp_id\n";
		$debug_skip_no_orig++;
		next;
	}

	# skip if this file or its partner was identified as empty
	if ($empty_files{$r1_orig_path}) {
		$debug_skip_empty++;
		next;
	}

	# find the matching R2 original path via pair_map
	my $r2_orig_path = $pair_map{$r1_orig_path};
	unless (defined $r2_orig_path) {
		print STDERR "DEBUG: no pair_map entry for r1=$r1_orig_path\n";
		$debug_skip_no_r2_pair++;
		next;
	}
	if ($empty_files{$r2_orig_path}) {
		$debug_skip_empty++;
		next;
	}

	# find the R2 unique name via pre-built reverse lookup hash
	my $r2_uniq = $path_to_uniq{$r2_orig_path};
	unless (defined $r2_uniq && $r2_uniq ne "") {
		print STDERR "DEBUG: no path_to_uniq entry for r2=$r2_orig_path\n";
		$debug_skip_no_r2_uniq++;
		next;
	}

	# strip lane/flow-cell fields to get the sample name
	my $tempnamecut = $uniq_samp_id =~ s/\_[[:alnum:]]+\_[[:alnum:]]+\_R1\_001.*\.fastq\.gz//r;

	my $lib_id = get_library_id($r1_orig_path);

	# Warn and skip if any required field is undef — prevents downstream errors
	if (!defined $tempnamecut || !defined $uniq_samp_id || !defined $r2_uniq || !defined $lib_id) {
		print STDERR "Warning: skipping row with undefined field(s):\n";
		print STDERR "  r1_uniq=$uniq_samp_id\n";
		print STDERR "  r2_uniq=" . (defined $r2_uniq  ? $r2_uniq  : "UNDEF") . "\n";
		print STDERR "  sample="  . (defined $tempnamecut ? $tempnamecut : "UNDEF") . "\n";
		print STDERR "  lib_id="  . (defined $lib_id    ? $lib_id    : "UNDEF") . "\n";
		next;
	}

	push @map_rows, {
		sample    => $tempnamecut,
		r1_uniq   => $uniq_samp_id,
		r2_uniq   => $r2_uniq,
		r1_orig   => $r1_orig_path,
		r2_orig   => $r2_orig_path,
		lib_id    => $lib_id,
	};
}

print STDERR "DEBUG map_rows summary:\n";
print STDERR "  samp_to_uniqsamp_hash keys: " . scalar(keys %samp_to_uniqsamp_hash) . "\n";
print STDERR "  R1 entries found: $debug_r1_count\n";
print STDERR "  skipped (not R1): $debug_skip_r1_filter\n";
print STDERR "  skipped (no orig path): $debug_skip_no_orig\n";
print STDERR "  skipped (empty file): $debug_skip_empty\n";
print STDERR "  skipped (no pair_map entry): $debug_skip_no_r2_pair\n";
print STDERR "  skipped (no path_to_uniq entry): $debug_skip_no_r2_uniq\n";
print STDERR "  rows pushed to map_rows: " . scalar(@map_rows) . "\n";

#-----------------------------------------------------------------------------

open(OUT_FH, ">$sampleID_path_map_tsv") || die "Could not open $sampleID_path_map_tsv\n";

print OUT_FH "SampleID\tUniqueFileName\tOriginalPath\n";
foreach my $row (sort { $a->{r1_uniq} cmp $b->{r1_uniq} } @map_rows) {
	my $samp_id_cut = $row->{r1_uniq} =~ s/\_[[:alnum:]]+\_[[:alnum:]]+\_R[12]\_001.*\.fastq\.gz//r;
	print OUT_FH "$samp_id_cut\t$row->{r1_uniq}\t$row->{r1_orig}\n";
	print OUT_FH "$samp_id_cut\t$row->{r2_uniq}\t$row->{r2_orig}\n";
}

close(OUT_FH);

#-----------------------------------------------------------------------------
# Chunk map rows into groups of 950 (hard limit is 1000; 950 gives safety margin)

my $chunk_size  = 950;
my $total_rows  = scalar @map_rows;
my $num_chunks  = int(($total_rows + $chunk_size - 1) / $chunk_size);  # ceiling division

if ($num_chunks > 1) {
	print STDERR "Total map rows: $total_rows — exceeds 1000 line limit.\n";
	print STDERR "Splitting into $num_chunks chunks of up to $chunk_size rows each.\n";
} else {
	print STDERR "Total map rows: $total_rows — single output file.\n";
}

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

#------------------------------------------------------------------------------
# Write map files and tar files — one pair per chunk

for my $chunk_idx (1 .. $num_chunks) {

	# Slice this chunk's rows out of @map_rows
	my $start = ($chunk_idx - 1) * $chunk_size;
	my $end   = $start + $chunk_size - 1;
	$end      = $total_rows - 1 if $end >= $total_rows;
	my @chunk_rows = @map_rows[$start .. $end];

	# Build chunk-suffixed output names (no suffix when only one chunk)
	my $chunk_suffix = ($num_chunks > 1) ? ".part$chunk_idx" : "";
	my $map_tsv  = "$output_fname${chunk_suffix}.map.tsv";
	my $tgz_file = "$output_fname${chunk_suffix}.tgz";

	# Write map file for this chunk
	open(OUT_FH, ">$map_tsv") || die "Could not open $map_tsv\n";
	print OUT_FH "SampleID\tR1_File\tR2_File\tLibraryID\n";
	foreach my $row (@chunk_rows) {
		print OUT_FH
			($row->{sample}  // "UNDEF") . "\t" .
			($row->{r1_uniq} // "UNDEF") . "\t" .
			($row->{r2_uniq} // "UNDEF") . "\t" .
			($row->{lib_id}  // "UNDEF") . "\n";
	}
	close(OUT_FH);
	print STDERR "Wrote map file: $map_tsv (" . scalar(@chunk_rows) . " rows)\n";

	# Write tar file for this chunk
	if ($write_file eq "Y") {
		print STDERR "Writing Tarfile: $tgz_file\n";

		my $tarfile = Archive::Tar->new;

		foreach my $row (@chunk_rows) {
			$tarfile->add_files($row->{r1_orig}) if defined $row->{r1_orig};
			$tarfile->add_files($row->{r2_orig}) if defined $row->{r2_orig};
		}

		# Rename to unique filenames inside the tar
		foreach my $row (@chunk_rows) {
			$tarfile->rename($row->{r1_orig}, $row->{r1_uniq}) if defined $row->{r1_orig};
			$tarfile->rename($row->{r2_orig}, $row->{r2_uniq}) if defined $row->{r2_orig};
		}

		$tarfile->write($tgz_file, COMPRESS_GZIP);
		print STDERR "Done writing: $tgz_file\n";
	}
}


###############################################################################

print STDERR "done.\n";

