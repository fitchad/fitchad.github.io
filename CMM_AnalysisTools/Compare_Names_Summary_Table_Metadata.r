#!/usr/bin/env Rscript

###############################################################################

library('getopt');

params=c(
        "input_file", "i", 1, "character",
        "factor_file", "f", 2, "character",
	"output_file", "o", 2, "character"
);

opt=getopt(spec=matrix(params, ncol=4, byrow=TRUE), debug=FALSE);
script_name=unlist(strsplit(commandArgs(FALSE)[4],"=")[1])[2];


usage = paste(
        "\nUsage:\n", script_name, "\n",
        "       -i <input summary_table.tsv file>\n",
        "       -f <factor file>\n",
	"	[-o <output file>]\n",
        "\n",
        "\n",
        "\n",
	"This script is hacked from Kelvin's plot stacked bar (or likely any of his scripts)\n",
	"It takes an input summary table and a metadata (factor) file\n",
	"Performs a setdiff and reports back unique (ie unmatched) samples between the two\n",
	"It also outputs the unmatched sampleIDs to a text file instead of printing on a PDF\n",
	"\n",
        "\n",
        "\n", sep="");

if(!length(opt$input_file)){
        cat(usage);
        q(status=-1);
}

InputFileName=opt$input_file;


if(length(opt$factor_file)){
        FactorFileName=opt$factor_file;
}else{
        cat(usage);
        q(status=-1);

}


if(length(opt$output_file)){
        OutputFileRoot=opt$output_file;
}else{
	OutputFileRoot=paste("NAMES.COMP", sep="")
#        OutputFileRoot=gsub("\\.summary_table\\.tsv$", ".NAMES.COMP", OutputFileRoot);
#        OutputFileRoot=gsub("\\.summary_table\\.xls$", "", OutputFileRoot);
        cat("No output file root specified.  Using NAMES.COMP  as output.\n");
}


#### Functions #####
load_factors=function(fname){
        factors=data.frame(read.table(fname,  header=FALSE, check.names=FALSE, row.names=1, comment.char="", quote="", sep="\t"));
        dimen=dim(factors);
	cat("\n","\n");
	cat("Loading -f : ", fname, "\n");
        cat("Rows Loaded: ", dimen[1], "\n");
        cat("Cols Loaded: ", dimen[2], "\n");
        return(factors);
}

load_summary_file=function(fname){
        counts_mat=data.frame(read.table(fname,  header=FALSE, check.names=FALSE, row.names=1, comment.char="", quote="", sep="\t"));
        dimen=dim(counts_mat);
        cat("\n","\n");
        cat("Loading -i: ", fname, "\n");
        cat("Rows Loaded: ", dimen[1], "\n");
        cat("Cols Loaded: ", dimen[2], "\n");
        return(counts_mat);


#	cat("\n","\n");
 #       cat("Loading Summary Table: ", fname, "\n");
  #      inmat=as.matrix(read.table(fname, sep="\t", header=TRUE, check.names=FALSE, comment.char="", row.names=1))
   #     counts_mat=inmat[,2:(ncol(inmat))];
#	dimen=dim(counts_mat);
#	cat("Rows Loaded: ", dimen[1], "\n");
#	cat("\n","\n");
 #       return(counts_mat);
}

#########################

orig_counts_mat=load_summary_file(InputFileName);

orig_factors_mat=load_factors(FactorFileName);


orig_factors_samples=rownames(orig_factors_mat);
orig_counts_samples=rownames(orig_counts_mat);
shared=intersect(orig_factors_samples, orig_counts_samples);


cat("\n\n");
cat("Samples not represented in sample sheet:\n", file=OutputFileRoot, sep="\n", append=TRUE);
excl_to_st=setdiff(orig_counts_samples, shared);
cat(excl_to_st, file=OutputFileRoot, sep="\n", append=TRUE);
cat(c("Samples not represented in", FactorFileName, ": ", length(excl_to_st)), "\n");
print(excl_to_st);


cat("\n\n");
cat("Samples not represented in fastq files:\n", file=OutputFileRoot, sep="\n", append=TRUE);
excl_to_fct=setdiff(orig_factors_samples, shared);
cat(excl_to_fct, file=OutputFileRoot, sep="\n", append=TRUE);
cat(c("Samples not represented in", InputFileName, ": ", length(excl_to_fct)), "\n");
print(excl_to_fct);
cat("\n\n");

num_shared=length(shared);
cat("Number of Shared Samples: ", num_shared, "\n");
cat("\n\n");

