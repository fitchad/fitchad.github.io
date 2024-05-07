#!/usr/bin/env Rscript
###############################################################################

library('getopt'); 

params=c("input_file", "i", 1, "character", 
	"drop_list", "d", 2, "character", 
	"taxa_column_name", "t", 2, "character", 
	"output_file", "o", 1, "character"
);

opt=getopt(spec=matrix(params, ncol=4, byrow=TRUE), debug=FALSE); 

script_name=unlist(strsplit(commandArgs(FALSE)[4],"=")[1])[2]; 

usage = paste(
	"\nUsage:\n\n", script_name, 
	"\n", " 
		-i <input summary_table.tsv>\n", 
	"	[-d <drop list>]\n", 
	"	[-t <taxa column name>]\n", 
	"	-o <output summary_table file name>\n", 
	"\n", 
	"This script will convert an epi2me summary table into a CMM compatible summary table,\n", 
	"writing out to a new file.\n", 
	"\n", 
	"if the -d variable is set, a user-defined set of columns can be removed. otherwise removed \n", 
	"columns will be the extra individual taxa level columns and the original totals column \n", 
	"\n", 
	"If the -t column is set, then the taxa column is user defined. Otherwise, the epi2me default \n", 
	"of 'tax' is set .\n", 
	"\n");

if(!length(opt$input_file) || !length(opt$output_file)){ 
  cat(usage);
  q(status=-1);
}


TaxaColumnName="tax"; 
if(length(opt$column_name)){
	TaxaColumnName=opt$taxa_column_name;
}

InputFileName=opt$input_file; 
DropList=opt$drop_list; 
OutputFileName=opt$output_file; 

OutputFileName=gsub("\\.summary_table\\.tsv", "", OutputFileName); 
OutputFileName=paste(OutputFileName, ".summary_table.tsv", sep=""); 
cat("\n");
cat("Input File Name: ", InputFileName, "\n"); 
cat("Output File Name: ", OutputFileName, "\n"); 
cat("Taxa Column Name: ", TaxaColumnName, "\n"); cat("\n"); 

if(length(opt$drop_list)){
	DropList=as.vector(read.table(opt$drop_list, header=FALSE, comment.char="#", sep="\t")[,1]);
}else{
	DropList=c("total", "superkingdom", "kingdom", "phylum", "class", "order", "family", "genus"); 
	cat("Drop list: ", DropList, "\n");
}

if(InputFileName==OutputFileName){ 
	cat("Error: Input and output summary table file name are the same.\n");
}

#######################################################################################################
#### Functions #####
load_factors=function(fname){ 
	factors=data.frame(read.table(fname, header=TRUE, check.names=FALSE, comment.char="", quote="", sep=",")); 
	dimen=dim(factors); 
	cat("\n","\n"); 
	cat("Loading : ", fname, "\n"); 
	cat("Rows Loaded: ", dimen[1], "\n"); 
	cat("Cols Loaded: ", dimen[2], "\n"); 
	return(factors);
}

#move column to first position
make_key=function(fname, key_col){
	key_col_val=fname[, key_col, drop=F]; 
	cnames=colnames(fname); 
	cnames=setdiff(cnames, key_col); 
	factors=cbind(key_col_val, fname[,cnames,drop=F]);
}

drop_columns=function(fname, drop_list){ 
	cnames=colnames(fname); 
	cnames=setdiff(cnames, drop_list); 
	factors=cbind(fname[,cnames,drop=F]);
}

write_table=function(fname, table){
        dimen=dim(table);
        cat("Rows Exporting: ", dimen[1], "\n");
        cat("Cols Exporting: ", dimen[2], "\n");
        write.table(table, fname, quote=F, row.names=F, sep="\t");
}

#############################################################################################################################


##Load Data
inmat=load_factors(InputFileName);

#Moving taxa column to the first column
inmat=make_key(inmat, TaxaColumnName);

#Drop extraneous columns
inmat=drop_columns(inmat, DropList);

#Grabbing taxonomy into a vector
new_col_names=inmat$TaxaColumnName;

#Dropping the taxa column now that it is saved in a vector
inmat=drop_columns(inmat, TaxaColumnName);

#transposing the table
inmat=as.data.frame(t(inmat));

#Renaming the columns with the taxonomy
colnames(inmat)<-new_col_names;

#capturing the sampleIDs
sample_ID=rownames(inmat);

num_samples=nrow(inmat);

#Calculating a totals vector for each row
total=c() 
for(samp_idx in 1:num_samples){ 
  t1=sum(inmat[samp_idx,]); 
  total=append(total, t1);
} 

#binding together the columns.
inmat=cbind(sample_ID, total, inmat);

#Table will write out without the row names, as they have been duplicated into the first column
write_table(OutputFileName, inmat);