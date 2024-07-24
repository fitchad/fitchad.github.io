#!/usr/bin/env Rscript

#Goals of Script
#Merge two sheets and a metadata file
#To Do
#1. Print out list of discarded rows

#Last Edit : 07/24/24

library("getopt");
library("reshape2");
library("graphics");
library("plyr")
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
  "slcolname", "S", 7, "character",
  "mdcolname", "M", 8, "character",
  "headcolumn", "H", 9, "character",
  "replace", "R", 10, "list"
  
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
  "[-S slcolname] Sample List column name to merge on \n",
  "\n",
  "[-M mdcolname] Metadata column name to merge on \n",
  "\n",
  "[-o outputfilename]\n",
  "\n",
  "[-L samplelist_columns_to_retain] (should be written as SampleID,SampleDate,DOB)\n",
  "\n",
  "[-C metadata_columns_to_retain] (should be written as SampleID,BMI,Age)\n",
  "\n",
  "[-H headcolumn] Name of column to move to column 1 position\n",
  "\n",
  "[-A all_merge] (should be L, R, or B. Default is discard if no match)\n",
  "\n",
  "[-R replace] ColA,ColB names. Will replace NA values in ColA with values from ColB\n",
  "\n",
  "This script is used to merge a list of sample IDs with a metadata file","\n",
  "in order to trim down a larger list of sample metadata to a specific set.", "\n",
  "\n",
  "It can also be used to merge two metadata sheets.", "\n",
  "\n",
  "If -S -M are not specified, the first column of each sheet will be used as the merge column.", "\n",
  "\n",
  "All metadata columns are retained, or specify retained columns by -L and -C", "\n",
  "Be sure to include the merge column in the list of retained columns", "\n",
  "\n",
  "HeadColumn -H can be used to move a named column to the first column of the sheet, \n",
  "If the same column name appears in both sheets and it is not the merge column", "\n",
  "a .x or .y should be appended to the column name (Left or Right sheet, resp)", "\n",
  "\n",
  "all_merge -A is used to do a Left, Right, or Both (union) merge, retaining all columns of respective sheet(s).", "\n",
  "The default option is to discard non-matches (intersection). ",
  "\n",
  "replace -R will replace NA values in ColA with values in ColB, if they exist\n",
  "This action occurs after merging DF1 and DF2. ColB will be removed from the final output.\n",
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
  OutputFname=tools::file_path_sans_ext(opt$samplelist)
  OutputFname=paste(OutputFname, ".Updated.tsv", sep="");
}else{
  OutputFname=opt$outputfilename;
}

if(!length(opt$columnslist)){
  ColumnsToRetainList=NULL
}else{
  ColumnsToRetainList=opt$columnslist;
  ColumnsToRetainList=strsplit(ColumnsToRetainList, ",")
  ColumnsToRetainList=as.character(unlist(ColumnsToRetainList[[1]]))
}

if(!length(opt$columnsmeta)){
  ColumnsToRetainMeta=NULL
}else{
  ColumnsToRetainMeta=opt$columnsmeta;
  ColumnsToRetainMeta=strsplit(ColumnsToRetainMeta, ",")
  ColumnsToRetainMeta=as.character(unlist(ColumnsToRetainMeta[[1]]))
}

if(!length(opt$slcolname)){
  SampleColName=NULL
}else{
  SampleColName=opt$slcolname
  
}
if(!length(opt$mdcolname)){
  MetadataColName=NULL
}else{    
  MetadataColName=opt$mdcolname
  
}

if(!length(opt$headcolumn)){
  HeadColumn=NA
}else{
  HeadColumn=opt$headcolumn
  
}

if(!length(opt$replace)){
  OldColumn=NULL
  NewColumn=NULL
}else{
  ColumnsToReplace=opt$replace;
  ColumnsToReplace=strsplit(ColumnsToReplace, ",")
  ColumnsToReplace=(unlist(ColumnsToReplace[[1]]))
  OldColumn=ColumnsToReplace[1]
  NewColumn=ColumnsToReplace[2]
  
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
#print(ColumnsToRetainMeta)

cat("\n", "\n");
cat("Summary Table Filename: ", SampleListFname, "\n", sep="");
cat("Metadata Filename: ", MetaDataFname, "\n", sep="");
cat ("Output Filename: ", OutputFname, "\n", sep="");
if(length(opt$headcolumn)){
  cat ("Head Column: ", HeadColumn, "\n", sep="");
}
if(length(opt$replace)){
  cat ("Merging", NewColumn, "into", OldColumn, "\n", sep=" ")
}

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

#  factors=as.data.frame(read.delim(fname, header=TRUE, row.names=1, check.names=FALSE, sep = "\t"));

###################
#### Load data ####
###################

#Load initial table, keep sampleIDs
#inmat=as.data.frame(read.table(SampleListFname, sep="\t", header=TRUE, row.names=1, check.names=FALSE, quote=NULL))
#CountsMat<-as.data.frame(inmat[,0, drop=FALSE]) #retains row names only

CountsMat<-load_factors(SampleListFname, ColumnsToRetainList)
NumberColumnsList <- ncol(CountsMat)

MetaDataFile<-load_factors(MetaDataFname, ColumnsToRetainMeta)
NumberColumnsMeta <- ncol(MetaDataFile)
#print (MetaDataFile)

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

#Updating column A with column B values, if specified.
if(!is.null(OldColumn)){
  nrows=length(SummaryMetaMerge[[OldColumn]])
  out=rep(0, nrows)
  #if(!is.na(as.character(SummaryMetaMerge[[OldColumn]][[i]]))){   
  for(i in 1:nrows){
    if(!is.na(SummaryMetaMerge[[OldColumn]][[i]])){
      out[i]=as.character(SummaryMetaMerge[[OldColumn]][[i]])
    }else{
      out[i]=as.character(SummaryMetaMerge[[NewColumn]][[i]])
    }
  }
  SummaryMetaMerge[OldColumn]<-out
  SummaryMetaMerge <-SummaryMetaMerge[ , !names(SummaryMetaMerge) %in% NewColumn]
}


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

if(!is.na(HeadColumn)){
  HeadCol<- subset(SummaryMetaMerge, select = c(HeadColumn))
  #HeadCol<- SummaryMetaMerge[ , names(SummaryMetaMerge) %in% HeadColumn] #this renames as "HeadColumn"
  NotHeadCol<-SummaryMetaMerge[ , !names(SummaryMetaMerge) %in% HeadColumn]
  SummaryMetaMerge<- cbind(HeadCol, NotHeadCol)
  cat('\n')
  head(SummaryMetaMerge)
}


### Writing CSV of reads comparison
write.table(SummaryMetaMerge, file=OutputFname, quote=FALSE, row.names = FALSE, sep="\t")

