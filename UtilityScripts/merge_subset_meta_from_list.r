#!/usr/bin/env Rscript


#Goals of Script
#Merge a list of sampleIDs and a metadata file
#To Do

#Last Edit : 12/1/20 4pm

library("getopt");
library("reshape2");
library("graphics");
library("plyr")
options(useFancyQuotes = F);


########################
###### Parameters ######
########################


params = c(
  "samplelist", "i", 1, "character",
  "metadata", "m", 2, "character",
  "outputfilename", "o", 3, "character",
  "columnstoretain", "C", 4, "list",
  "all_merge", "A", 5, "character"
  
);

opt=getopt(spec = matrix(params, ncol=4, byrow=TRUE), debug=FALSE);
script_name=unlist(strsplit(commandArgs(FALSE) [4], "=")[1])[2];

usage = paste(
  "\nUsage:\n", script_name, "\n",
  "\n",
  "-i <samplelist>\n",
  "\n",
  "-m <metadata>\n",
  "\n",
  "[-o outputfilename]\n",
  "\n",
  "[-C metadata_columns_to_retain] (should be written as 4,5,6,7)\n",
  "\n",
  "[-A all_merge] (should be L, R, or B. Default is discard if no match)\n",
  "\n",
  "This script is used to merge a list of sample IDs with a metadata file","\n",
  "in order to trim down a larger list of sample metadata to a specific set", "\n",
  "\n",
  "The input list of samples is flexible as the script will just grab the first column",
  "and ignore the remaining columns",
  "\n",
  "\n",
  "All metadata columns are retained, or specify retained columns by -C",
  "\n",
  "all_merge is used to do a Left, Right, or Both merge, retaining all columns of respective sheet(s)",
  "default if option isn't selected is to discard non-matches. ",
  "\n",
  "\n"
  
);

if(!length(opt$samplelist)){
  cat(usage);
  q(status=-1);
}

if(!length(opt$metadata)){
  cat(usage);
  q(status=-1);
}else{
  MetaDataFname=opt$metadata;
}


if(!length(opt$outputfilename)){
  OutputFname=basename(opt$samplelist)
  #OutputFname=gsub(".tsv", "", OutputFname);
  OutputFname=paste(OutputFname, ".Updated", sep="");
}else{
  OutputFname=opt$outputfilename;
}



if(!length(opt$columnstoretain)){
  ColToRetain=NULL
}else{
  ColToRetain=opt$columnstoretain;
  ColToRetain=strsplit(ColToRetain, ",")
  ColToRetain=as.numeric(unlist(ColToRetain[[1]]))
}

ALL.X=FALSE
ALL.Y=FALSE
ALL=FALSE
if(!length(opt$all_merge)){
  RetainAll=NULL
}else{
  RetainAll=opt$all_merge;
  if(RetainAll!="L" && RetainAll!="R" && RetainAll!= "B"){
    print("Not a valid option, use L, R, or B. Setting to False")
    
  }else if (RetainAll=="L"){
    ALL.X=TRUE
  }else if (RetainAll=="R"){
    ALL.Y=TRUE
  }else if (RetainAll=="B"){
    ALL=TRUE
    
  }
}







SampleListFname <- opt$samplelist
#print(ColToRetain)

cat("\n", "\n");
cat("Summary Table Filename: ", SampleListFname, "\n", sep="");
cat("Metadata Filename: ", MetaDataFname, "\n", sep="");
cat ("Output Filename: ", OutputFname, "\n", sep="");

cat("\n", "\n");


######################
###### Functions #####
######################


#Load factors
load_factors=function(fname){
  factors=as.data.frame(read.delim(fname, header=TRUE, row.names=1, check.names=FALSE, sep = "\t"));
  if(!is.null(ColToRetain)){
    factors=factors[c(ColToRetain-1)]
  }
  return(factors);
  
}



###################
#### Load data ####
###################

#Load initial table, keep sampleIDs
inmat=as.data.frame(read.table(SampleListFname, sep="\t", header=TRUE, row.names=1, check.names=FALSE, quote=NULL))
CountsMat<-as.data.frame(inmat[,0, drop=FALSE]) #retains row names only

MetaDataFile<-load_factors(MetaDataFname)
NumberColumnsMeta <- ncol(MetaDataFile)

cat("\n")
cat("Retaining Metadata Columns:", "\n")
print(colnames(MetaDataFile))
cat("\n")


##########################
###### Main Program ######
##########################


#Merging Summary Table Reads and Metadata File
SummaryMetaMerge<- merge(CountsMat, MetaDataFile, by="row.names", all.x=ALL.X, all.y=ALL.Y, all=ALL)

names(SummaryMetaMerge)[names(SummaryMetaMerge)=="Row.names"] <- "SampleID"

head(SummaryMetaMerge)

cat('\n')
cat("Number of rows in list: ", nrow(CountsMat))
cat('\n')
cat("Number of rows in metadata: ", nrow(MetaDataFile))
cat('\n')
cat("Number of rows in merged file: ", nrow(SummaryMetaMerge))
cat('\n')

if(nrow(CountsMat)==nrow(SummaryMetaMerge)){
  cat("List and merged file row counts match")
  cat('\n')
}else{
  cat("****** Warning, some SampleIDs may not have matched ********")
  cat('\n')
}

### Writing CSV of reads comparison
write.table(SummaryMetaMerge, file=OutputFname, quote=FALSE, row.names = FALSE, sep="\t")

