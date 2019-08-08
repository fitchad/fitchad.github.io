#!/usr/bin/env Rscript


#Goals of Script
#Import summary table and metadata file
#cut summary table at various read counts
#plot how many samples remain for each metadata category at each cut

#To Do

#Graph of difference between each cut of table, or each cut vs original? 
#plot all the cuts on the same plot?
#Summary Stats - at least the number of each in original vs each successive cut
#option to specify the number of plots per page

#Last Edit : 10/3/18 4pm

library("ggplot2");
library("getopt");
library("reshape2");
library("graphics");
library("plyr")
options(useFancyQuotes = F);


########################
###### Parameters ######
########################


params = c(
  "summarytable", "i", 1, "character",
  "metadata", "m", 2, "character",
  "outputfilename", "o", 3, "character",
  "readsstepsizes", "s", 4, "integer",
  "numberofsteps", "n", 5, "integer",
  "columnstoretain", "C", 6, "list"

);

opt=getopt(spec = matrix(params, ncol=4, byrow=TRUE), debug=FALSE);
script_name=unlist(strsplit(commandArgs(FALSE) [4], "=")[1])[2];

usage = paste(
  "\nUsage:\n", script_name, "\n",
  "\n",
  "-i <summarytable>\n",
  "\n",
  "-m <metadata>\n",
  "\n",
  "[-o outputfilename]\n",
  "\n",
  "[-s reads_step_sizes] (ie remove samples with < -s at each cut) \n",
  "\n",
  "[-n number_of_steps] (ie how many times to cut the table)\n",
  "\n",
  "[-C metadata_columns_to_retain] (should be written as 4,5,6,7)\n",
  "\n",
  "This script is used to compare surviving sample numbers per metadata","\n",
  "group at various read count steps", "\n",
  "\n",
  "The table is stepped by a user read count, or default of 500 reads",
  "\n",
  "The number of steps can also be specified. Default is 3 steps","\n",
  "\n",
  "All metadata columns are analyzed, or specify columns by -C",
  "\n",
  "\n",
  "\n"
  
);

if(!length(opt$summarytable)){
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
  OutputFname=basename(opt$summarytable)
  OutputFname=gsub(".pdf", "", OutputFname);
}else{
  OutputFname=opt$outputfilename;
}

OutputFname=paste(OutputFname, ".Metadata.Reads.Steps.pdf", sep="");

if(!length(opt$readsstepsizes)){
  ReadsStepSize = 500;
}else{
  ReadsStepSize = opt$readsstepsizes;
}

if(!length(opt$numberofsteps)){
  NumberOfSteps=3;
}else{
  NumberOfSteps = opt$numberofsteps;
}

if(!length(opt$columnstoretain)){
  ColToRetain=NULL
}else{
  ColToRetain=opt$columnstoretain;
  ColToRetain=strsplit(ColToRetain, ",")
  ColToRetain=as.numeric(unlist(ColToRetain[[1]]))
}
  


SummaryTableFname <- opt$summarytable
#print(ColToRetain)

cat("\n", "\n");
cat("Summary Table Filename: ", SummaryTableFname, "\n", sep="");
cat("Metadata Filename: ", MetaDataFname, "\n", sep="");
cat ("Output Filename: ", OutputFname, "\n", sep="");
cat ("Step size for table: ", ReadsStepSize, "\n", sep="");

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

#Slicing table
slice_table=function(df, slicesize){
   keep_samples=df[df[,2]>slicesize,]
   return (keep_samples);
}


###################
#### Load data ####
###################

#Load initial table, keep sampleIDs and read counts
inmat=as.data.frame(read.table(SummaryTableFname, sep="\t", header=TRUE, row.names=1, check.names=FALSE, quote=NULL))
CountsMat=inmat[,1]


MetaDataFile<-load_factors(MetaDataFname)
NumberColumnsMeta <- ncol(MetaDataFile)

cat("Retaining Metadata Columns:", "\n")
print(colnames(MetaDataFile))
cat("\n")

#Setting break points for histogram
HistoBreakPoint = max(as.numeric(CountsMat))/5
TempList = c(0,1,2,3,4,5)
HistoBreakPoints = round(HistoBreakPoint*TempList)

##########################
###### Main Program ######
##########################

pdf(OutputFname, width=11, height=9.5) #open PDF writer

#Creating a simplified counts df from the summary table
CountsMat<-as.data.frame(inmat[,1, drop=FALSE]) #retains row names

#Merging Summary Table Reads and Metadata File
SummaryMetaMerge<- merge(CountsMat, MetaDataFile, by="row.names")



maxvect<- integer() #vector used to store maximum values in each metadata column. used to keep plot axis consistent. 

for(ix in 0:NumberOfSteps){
  #sets the plots per page
  if(NumberColumnsMeta>10){
    par(mfrow=c(5,4))
    CEX = 1 #sets size of text of the initial descriptive (text only) plot
  }else{
    #par(mfrow = c(round(NumberColumnsMeta/2),2))
    par(mfrow=c(3,4))
    CEX = 1
  }
  
  if(ix == 0){
    ReadsStepSizeLoop = 0
  }else{
    ReadsStepSizeLoop = ix*ReadsStepSize
  }

  StepTable <- slice_table(SummaryMetaMerge, ReadsStepSizeLoop)
  print(head(StepTable))
  #Initial plot per each sliced table. Text only with cut size and remaining sample #
  p <- plot.new()
  p+text(x=.50,.50, cex=CEX, c(paste("For Samples with min:", ReadsStepSizeLoop, "Reads",
                                     "\n",
                                     "\n",
                                     "\n",
                                     "Remaining Samples: ", nrow(StepTable))))
  
 
  #capturing the max value of each metadata column in a vector, using to keep plot axes the same
  if (ix==0){
    for (iz in 1:ncol(StepTable)){
      #print(StepTable)
      #a<-na.omit(StepTable)
      m<-count(StepTable, iz)
      M<- max(m$freq)
      maxvect<- c(maxvect, M) #includes rownames(1), total(2)

    }
  #  print(maxvect)
  }
  #Printing a summary to stdout
  cat("Summary of", basename(SummaryTableFname), "at N cutoff:", ReadsStepSizeLoop, "\n")
  cat(capture.output(summary(StepTable[,2])),sep="\n", file="")
  cat ("Remaining Samples", nrow(StepTable))
  cat ("\n")
  
  
  #Looping through metadata and producing plots
  for (iy in 2:ncol(StepTable)){
    #currently, column 1 is sample names, col 2 is total reads, col 3+ is metadata
    if(iy ==2){
      x<-as.vector(StepTable[,iy])
      #h<-hist(x, breaks=5, main=colnames(StepTable[iy]))
      h<-hist(x, breaks=HistoBreakPoints, las=2, freq=F, main = "Total Reads")
      
    }else{
      x<-table(StepTable[,iy])
      b<-barplot(x, main=colnames(StepTable[iy]), las=2, ylim=c(0,maxvect[iy]))
      
    }
    
  }
  
  
}
dev.off()


print(warnings())







