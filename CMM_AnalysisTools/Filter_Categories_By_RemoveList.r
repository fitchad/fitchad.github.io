#!/usr/bin/env Rscript
#edited: ACF 7/31/19
###############################################################################

library('getopt');

params=c(
	"input_file", "i", 1, "character",
	"remove_list", "l", 1, "character",
	"output_file", "o", 2, "character"
);

opt=getopt(spec=matrix(params, ncol=4, byrow=TRUE), debug=FALSE);
script_name=unlist(strsplit(commandArgs(FALSE)[4],"=")[1])[2];

usage = paste (
	"\nUsage:\n\n", script_name,
	"\n",
	"	-i <input summary table.xls>\n",
	"	-l <list of categories to remove>\n",
	"	[-o <output summary table file name>]\n",
	"\n",	
	"This script will read in a summary table and remove the categories\n",
	"that are specified in the list file.\n",
	"\n",
	"\n");

if(!length(opt$input_file) || !length(opt$remove_list)){
	cat(usage);
	q(status=-1);
}

if(!length(opt$output_file)){
	outputroot=gsub("\\.summary_table\\.xls", "", opt$input_file);
	outputroot=gsub("\\.summary_table\\.tsv", "", opt$input_file);
	OutputFileName = paste(outputroot, ".list_filtered.summary_table.tsv", sep="");
}else{
	outputroot=gsub("\\.summary_table\\.xls", "", opt$output_file);
	outputroot=gsub("\\.summary_table\\.tsv", "", opt$output_file);
	OutputFileName=opt$output_file;
}

###############################################################################

InputFileName=opt$input_file;
RemoveList=opt$remove_list;

cat("\n")
cat("Input File Name: ", InputFileName, "\n");
cat("Remove List Name: ", RemoveList, "\n");
cat("Output File Name: ", OutputFileName, "\n");       
cat("\n");

###############################################################################
###############################################################################

load_summary_table=function(summary_table_fn){
        # Load data
        cat("Loading Matrix (", summary_table_fn, ") ...\n", sep="");
        inmat=as.matrix(read.table(summary_table_fn, sep="\t", header=TRUE, check.names=FALSE, row.names=1, quote=""))

        #cat("\nOriginal Matrix:\n")
        #print(inmat);

        # Grab columns we need into a vector, ignore totals, we won't trust it.
        counts_mat=inmat[,2:(ncol(inmat))];
        #cat("\nCounts Matrix:\n");
        #print(counts_mat);

        num_samples=nrow(counts_mat);
        num_categories=ncol(counts_mat);
        sample_names=rownames(counts_mat);

        cat("\n");
        cat("Num Samples: ", num_samples, "\n");
        cat("Num Categories: ", num_categories, "\n");
        cat("\n");
        return(counts_mat);
}

###############################################################################

load_ids=function(list_fn){
        cat("Loading List (", list_fn, ") ...\n", sep="");
        list=scan(file=list_fn, what="complex", sep="\t");
        return(list);
}

###############################################################################


plot_text=function(strings){
  orig_par=par(no.readonly=T);
  
  par(mfrow=c(1,1));
  par(family="Courier");
  par(oma=rep(.5,4));
  par(mar=rep(0,4));
  
  num_lines=length(strings);
  
  top=max(as.integer(num_lines), 40);
  
  plot(0,0, xlim=c(0,top), ylim=c(0,top), type="n",  xaxt="n", yaxt="n",
       xlab="", ylab="", bty="n", oma=c(1,1,1,1), mar=c(0,0,0,0)
  );
  for(i in 1:num_lines){
    #cat(strings[i], "\n", sep="");
    text(0, top-i, strings[i], pos=4, cex=.8);
  }
  
  par(orig_par);
}

##############################################################################


# Load counts matrix
counts_mat=load_summary_table(InputFileName);
num_categories=ncol(counts_mat);
num_samples=nrow(counts_mat);

# Load remove list IDs
remove_id_list=load_ids(RemoveList);
num_removal=length(remove_id_list);
cat("Num categories to remove: ", num_removal, "\n");

# Get the category names
category_names=colnames(counts_mat);
# Get the sample names
sample_names=rownames(counts_mat)

# Get indices for the columns we want to remove
rem_idx=num_removal;
cat("\nRemoval Categories:\n");
for(i in 1:num_removal){
	cat("\t", remove_id_list[i]);
	rem_idx[i]=which(remove_id_list[i]==category_names);
	cat(" / ", "Column_ID", rem_idx[i], "\n", sep=" ");
	cat ("Sample_ID\tRead_Count\n")
	for (j in 2:num_samples){
	  if (counts_mat[j,rem_idx[i]] > 0){
	    cat (sample_names[j], "\t", counts_mat[j,rem_idx[i]], "\n")

	}
	}
}

# Remove the columns
outmat=counts_mat[,-rem_idx];

# Remove num categories left
num_remaining_categories=ncol(outmat);
cat("\nNum remaining categories: ", num_remaining_categories, "\n");

###############################################################################
# Output
cat("\nWriting New Matrix...\n");
fc=file(OutputFileName, "w");

removed_samples=character();

write(paste("sample_id", "total", paste(colnames(outmat), collapse="\t"), sep="\t"), file=fc);
sample_names=rownames(counts_mat);
for(samp_idx in 1:num_samples){
	total=sum(outmat[samp_idx,]);

	if(total==0){
		cat("WARNING: ", sample_names[samp_idx], " was removed because total equaled zero (after filtering).\n", sep="");
		removed_samples=c(removed_samples, sample_names[samp_idx]);
	}else{
		outline=paste(sample_names[samp_idx],total,paste(outmat[samp_idx,], collapse="\t"), sep="\t");
		write(outline, file=fc);
	}
}
close(fc);	

########################################################################
#Log
sink((paste(OutputFileName, ".log.txt", sep="")), append=TRUE);
cat("Log Started\n")
cat("\n", date(), sep="")


cat("\n")
cat("Input File Name: ", InputFileName, "\n");
cat("Remove List Name: ", RemoveList, "\n");
cat("Output File Name: ", OutputFileName, "\n");       
cat("\n");

cat("\nCategories Removed with read counts per Sample ID\n")

for(i in 1:num_removal){
  cat("\t", remove_id_list[i]);
  rem_idx[i]=which(remove_id_list[i]==category_names);
  cat(" / ", "Column_ID", rem_idx[i], "\n", sep=" ");
  cat ("Sample_ID\tRead_Count\n")
  for (j in 2:num_samples){
    if (counts_mat[j,rem_idx[i]] > 0){
      cat (sample_names[j], "\t", counts_mat[j,rem_idx[i]], "\n")
      
    }
  }

}

cat("\nNum remaining categories: ", num_remaining_categories, "\n");

sink()

###############################################################################

if(length(removed_samples)>0){
	fc=file(paste(outputroot, ".removed_samples.list", sep=""), "w");
	write(file=fc, removed_samples);
	close(fc);
}

cat("Done.\n")
warns=warnings();
if(!is.null(warns)){
	print(warnings());
}
q(status=0)
