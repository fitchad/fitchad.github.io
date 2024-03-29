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
	"It takes two .tsv files as input and uses data from the first column of each,  \n",
	"performing an intersection on the columns, and a setdiff for each column vs the intersection. \n",
	"Unique (ie unmatched) samples, as well as matches between the two columns are reported \n",
	"to the screen and to a text file\n",
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
        cat("Loading : ", fname, "\n");
        cat("Rows Loaded: ", dimen[1], "\n");
        cat("Cols Loaded: ", dimen[2], "\n");
        return(factors);
}


#########################

orig_counts_mat=load_factors(InputFileName);

orig_factors_mat=load_factors(FactorFileName);


orig_factors_samples=rownames(orig_factors_mat);
orig_counts_samples=rownames(orig_counts_mat);
shared=intersect(orig_factors_samples, orig_counts_samples);



cat("\n\n");
excl_to_st=setdiff(orig_counts_samples, shared);
cat("Samples not represented in ", basename(FactorFileName), ": ", length(excl_to_st), file=OutputFileRoot, sep="", append=TRUE);
cat("", file=OutputFileRoot, sep="\n", append=TRUE)
cat(excl_to_st, file=OutputFileRoot, sep="\n", append=TRUE);
cat(c("Samples not represented in", basename(FactorFileName), ":", length(excl_to_st)), "\n");
print(excl_to_st);



cat("\n\n");
excl_to_fct=setdiff(orig_factors_samples, shared);
cat("\n", "Number of Samples not represented in ", basename(InputFileName), ": ", length(excl_to_fct), file=OutputFileRoot, sep="", append=TRUE);
cat("", file=OutputFileRoot, sep="\n", append=TRUE)
cat(excl_to_fct, file=OutputFileRoot, sep="\n", append=TRUE);
cat(c("Samples not represented in", basename(InputFileName), ":", length(excl_to_fct)), "\n");
print(excl_to_fct);


cat("\n\n");

#num_shared=length(shared);
#cat("\n", "Number of Shared Samples: ", num_shared, file=OutputFileRoot, sep="", append=TRUE)
#cat("", shared, file=OutputFileRoot, sep="\n", append=TRUE)
#cat("Number of Shared Samples:", num_shared, "\n");
#print(shared)
cat("\n\n");

