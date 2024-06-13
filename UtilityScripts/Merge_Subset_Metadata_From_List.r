#!/usr/bin/env Rscript

#Goals of Script
#Merge a list of sampleIDs and a metadata file
#To Do
#2. Add an output list of discarded rows

#Last Edit : 06/12/24 4pm
#added the ability to merge on multiple columns

library("getopt");
library("reshape2");
library("graphics");
library("plyr");

options(useFancyQuotes = F);


########################
###### Parameters ######
########################


params = c(
  "samplelist", "l", 1, "character",
  "metadata", "m", 2, "character",
  "outputfilename", "o", 3, "character",
  "columnslist", "L", 4, "list",
  "columnsmeta", "C", 5, "list",
  "all_merge", "A", 6, "character",
  "slcolname", "S", 7, "list",
  "mdcolname", "M", 8, "list",
  "headcolumn", "H", 9, "character"
  
);

opt=getopt(spec = matrix(params, ncol=4, byrow=TRUE), debug=FALSE);
script_name=unlist(strsplit(commandArgs(FALSE) [4], "=")[1])[2];

usage = paste(
  "\nUsage:\n", script_name, "\n",
  "\n",
  "-l <samplelist> (can also be a metadata sheet) \n",
  "\n",
  "-m <metadata>\n",
  "\n",
  "[-S slcolname] List of colnames from Sample List to merge on \n",
  "\n",
  "[-M mdcolname] List of colnames from Metadata to merge on \n",
  "\n",
  "[-o outputfilename]\n",
  "\n",
  "[-L samplelist_columns_to_retain] (should be written as 4,5,6,7)\n",
  "\n",
  "[-C metadata_columns_to_retain] (should be written as 4,5,6,7)\n",
  "\n",
  "[-H headcolumn] Name of column to move to column 1 position\n",
  "\n",
  "[-A all_merge] (should be L, R, or B. Default is discard if no match)\n",
  "\n",
  "This script is used to merge two sheets","\n",
  "\n",
  "It can also be used to merge two metadata sheets.", "\n",
  "\n",
  "If no column names are specified, the first column of each will be used.",
  "\n",
  "More than 1 column name can be supplied for the -S and -M in order to merge on multiple columns.\n",
  "The supplied lists of column names must be the same length and in the merge order.\n",
  "\n",
  "All metadata columns are retained, or specify retained columns by -L and -C", "\n",
  "Be sure to include the ID column in the list of retained columns", "\n",
  "\n",
  "HeadColumn -H can be used to move a named column to the first column of the sheet, \n",
  "If the same column name appears in both sheets and it is not the merge column", "\n",
  "a .x or .y should be appended to the column name (Left or Right sheet, resp)", "\n",
  "\n",
  "All_merge -A is used to do a Left, Right, or Both (union) merge, retaining all columns of respective sheet(s).", "\n",
  "The default option if -A isn't declared is to discard non-matches (intersection). ",
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
  OutputFname=tools::file_path_sans_ext(basename(opt$samplelist));
  OutputFname=paste(OutputFname, ".Updated.tsv", sep="");
}else{
  OutputFname=opt$outputfilename;
}

if(!length(opt$columnslist)){
  ColumnsToRetainList=NULL
}else{
  ColumnsToRetainList=opt$columnslist;
  ColumnsToRetainList=strsplit(ColumnsToRetainList, ",")
  ColumnsToRetainList=as.numeric(unlist(ColumnsToRetainList[[1]]))
}

if(!length(opt$columnsmeta)){
  ColumnsToRetainMeta=NULL
}else{
  ColumnsToRetainMeta=opt$columnsmeta;
  ColumnsToRetainMeta=strsplit(ColumnsToRetainMeta, ",")
  ColumnsToRetainMeta=as.numeric(unlist(ColumnsToRetainMeta[[1]]))
}

if(!length(opt$slcolname)){
  SampleColName=NULL
}else{
  SampleColName=opt$slcolname
  SampleColName=strsplit(SampleColName, ",")
  SampleColName=unlist(SampleColName[[1]])
     
}
if(!length(opt$mdcolname)){
  MetadataColName=NULL
}else{    
  MetadataColName=opt$mdcolname
  MetadataColName=strsplit(MetadataColName, ",")
  MetadataColName=unlist(MetadataColName[[1]])

}

if(length(MetadataColName)!=length(SampleColName)){
  cat("**** Mismatch in number of merge columns ****\n")
  cat(usage);
  q(status=-1);
}



if(!length(opt$headcolumn)){
  HeadColumn=NULL
}else{
  HeadColumn=opt$headcolumn
  
}



ALL.X=FALSE
ALL.Y=FALSE
if(!length(opt$all_merge)){
  RetainAll=NULL
}else{
  RetainAll=opt$all_merge;
  if(RetainAll!="L" && RetainAll!="R" && RetainAll!= "B"){
    cat("\n")
    cat("*********Warning**********\n")
    cat(RetainAll, "is not a valid option, use L, R, or B. Setting to False (ie intersection)\n")
    cat("***************************\n")
  }else if (RetainAll=="L"){
    ALL.X=TRUE
  }else if (RetainAll=="R"){
    ALL.Y=TRUE
  }else if (RetainAll=="B"){
    ALL.X=TRUE
    ALL.Y=TRUE
    
  }
}

SampleListFname <- opt$samplelist

cat("\n", "\n");
cat("Summary Table Filename: ", SampleListFname, "\n", sep="");
cat("Metadata Filename: ", MetaDataFname, "\n", sep="");
cat ("Output Filename: ", OutputFname, "\n", sep="");
cat ("Head Column: ", HeadColumn, "\n", sep="");

cat("\n", "\n");


######################
###### Functions #####
######################


#Load factors
load_factors=function(fname, cols){
  factors=as.data.frame(read.delim(fname, header=TRUE, check.names=FALSE, sep = "\t"));
  if(!is.null(cols)){
    factors=factors[c(cols)]
  }
  return(factors);
  
}


###################
#### Load data ####
###################

CountsMat<-load_factors(SampleListFname, ColumnsToRetainList)
NumberColumnsList <- ncol(CountsMat)

MetaDataFile<-load_factors(MetaDataFname, ColumnsToRetainMeta)
NumberColumnsMeta <- ncol(MetaDataFile)
print (MetaDataFile)

BY.X=SampleColName
if(is.null(SampleColName)){
  BY.X=colnames(CountsMat[1])
}

BY.Y=MetadataColName
if(is.null(MetadataColName)){
  BY.Y=colnames(MetaDataFile[1])
}

cat("\n")
cat("Retaining SampleList Columns:", "\n")
print(colnames(CountsMat))
cat("\n")


cat("\n")
cat("Retaining Metadata Columns:", "\n")
print(colnames(MetaDataFile))
cat("\n")


##########################
###### Main Program ######
##########################


#Merging Summary Table Reads and Metadata File


SummaryMetaMerge<- merge(CountsMat, MetaDataFile, by.x=BY.X, by.y=BY.Y, all.x=ALL.X, all.y=ALL.Y)

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
  cat ("This may be intentional depending on the options/inputs selected")
  cat('\n')
}

if(!is.null(HeadColumn)){
  HeadCol<- subset(SummaryMetaMerge, select = c(HeadColumn))
  NotHeadCol<-SummaryMetaMerge[ , !names(SummaryMetaMerge) %in% HeadColumn]
  SummaryMetaMerge<- cbind(HeadCol, NotHeadCol)
  head(SummaryMetaMerge)
}


### Writing CSV of reads comparison
write.table(SummaryMetaMerge, file=OutputFname, quote=FALSE, row.names = FALSE, sep="\t")

