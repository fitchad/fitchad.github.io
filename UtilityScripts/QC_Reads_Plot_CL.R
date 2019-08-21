#!/usr/bin/env Rscript

#Author: Adam Fitch
#Last Edit : 8/2/19 1pm

library("ggplot2");
library("getopt");
library("reshape2");

options(useFancyQuotes = F);


#TO DO:
#1. output - get directory
#2. Add table summary to first page of PDF
#3. Add summary statistics? Mean / Median by category?
#4. incorporate metadata


########################
###### Parameters ######
########################


params = c(
  "qcreport", "i", 1, "character",
  "metadata", "m", 2, "character",
  "metadatacolumn", "c", 3, "integer",
  "outputfilename", "o", 4, "character",
  "samplesperplot", "s", 5, "integer"
  
);

opt=getopt(spec = matrix(params, ncol=4, byrow=TRUE), debug=FALSE);
script_name=unlist(strsplit(commandArgs(FALSE) [4], "=")[1])[2];

usage = paste(
  "\nUsage:\n", script_name, "\n",
  "\n",
  "-i <qcreport>\n",
  "\n",
  "[-m metadata]\n",
  "\n",
  "[-c metadatacolumn]\n",
  "\n",
  "[-o outputfilename]\n",
  "\n",
  "[-s samplesperplot]\n",
  "\n",
  "This script will take in a QC summary report","\n",
  "and generate bar plots for each sample/read at each filter", "\n",
  "\n",
  "Metadata Column is the column number of the metadata you want to use","\n",
  "to split the plots (eg a sample type column)", "\n","\n",
  "Plots are split by a user defined samples size, or default of 50 per plot",
  "\n",
  "\n",
  "Plots are saved in the same directory as the QC report",
  "\n",
  "\n"
  
);

if(!length(opt$qcreport)){
  cat(usage);
  q(status=-1);
}else{
  QCReportFname <- opt$qcreport
}

if(!length(opt$metadata)){
  MetadataFname=NULL
}else{
  MetadataFname<- opt$metadata
}


if(!length(opt$metadatacolumn)){
  MetadataColumn=NULL
}else{
  MetadataColumn=opt$metadatacolumn
}


if(!length(opt$outputfilename)){
  OutputFname=basename(opt$qcreport)
  OutputFname=gsub(".tsv", "",OutputFname);
}else{
  OutputFname=opt$outputfilename;
}

OutputFname=paste(OutputFname, ".QCReadsBarplot.pdf", sep="");



if(!length(opt$samplesperplot)){
  SamplesPerPlot = 50;
}else{
  SamplesPerPlot = opt$samplesperplot;
}

#when applying 6 filters, each samples has a total of 13 entries on log
SamplesPerPlot = SamplesPerPlot*13



cat("\n")
cat("QCReportFname: ", QCReportFname, "\n", sep="");
if(!is.null(MetadataFname)){
  cat("MetadataFname: ", MetadataFname, "\n", sep="");
}
cat("\n")
cat ("Output Filename Root: ", OutputFname, "\n", sep="")
cat("\n")


########################
###### Functions #######
########################


split_table <- function(table){
  if (NumSampleIDs>SamplesPerPlot){
    cat ("
         Table has greater than", SamplesPerPlot/13, "samples, splitting into chunks
         \n")
    tablecomp.split <- split(table, (as.numeric(rownames(table))-1) %/% SamplesPerPlot)
  }
  else{
    cat("
        Less than", SamplesPerPlot/13, "samples, plotting all on a single plot
        \n")
    tablecomp.split <- split(table, (as.numeric(rownames(table))-1) %/% SamplesPerPlot)
  }
  return (tablecomp.split);
  
}

melt_TableMerge<-function(table){
  df.long<- melt(table)
  #df.long<- df.long[,1:3]
  return(df.long)
  
}
plot_table<- function(table, yAxisLimit){
  plotted_table <- ggplot(table, aes(x=as.character(X..Name), value, fill=Read_Filter, width=0.75))+
    geom_bar(stat="identity",position="dodge", width = 0.5)+
    coord_cartesian(ylim=c(0,TableMaxReads))+
    facet_grid(rows=vars(Filter)) +
    theme(axis.text.x=element_text(angle =90, size=11, hjust=1, vjust=0.5))+
    labs(title="", x="SampleID", y="Reads Count") +
	geom_hline(yintercept=3000)
  
  
  return(plotted_table);
  
}

#Load factors
load_factors=function(fname){
  factors=as.data.frame(read.delim(fname, header=TRUE, row.names=1, check.names=FALSE, sep = "\t"));
  if(!is.null(ColToRetain)){
    factors=factors[c(ColToRetain-1)]
  }
  return(factors);
  
}




#####Loading Data

QC_Table=as.data.frame(read.csv(QCReportFname, sep="\t", quote=NULL))

##Trimming table to sampleID / read type / filter used / reads count
QC_Table_Reads <- QC_Table[,1:4]
#Creating a combination "Reads_Filter" Column
Read_Filter <- as.vector(paste(QC_Table_Reads$Read, QC_Table_Reads$Filter, sep="_"))


Paired_vect <- QC_Table_Reads$Read == "paired"

##Dividing paired merged reads by 2 as this set is double counted
for (i in 1:length(Paired_vect)){
  if (Paired_vect[i]=="TRUE"){
    QC_Table_Reads[i,]$NumRecords <- QC_Table_Reads[i,]$NumRecords/2}
}


##Counting the number of unique sampleIDs
NumSampleIDs <- nlevels(unique(QC_Table$X..Name))
print(NumSampleIDs)
##Getting max read value to keep ylim consistent across plots
TableMaxReads <- max(QC_Table_Reads$NumRecords)

#Limiting the y axis. Samples with reads above this limit make the plots 
#difficult to read for lower output samples. 
if (TableMaxReads > 30000){
  TableMaxReads <- 30000
}


##Modifying QC table. Adding a combined Read_Filter column, and renaming the Filter column
##so that it is ordered correctly in the facet grid

QC_Table_Reads<- cbind(QC_Table_Reads, Read_Filter)
QC_Table_Reads$Filter <- as.character(QC_Table_Reads$Filter)
QC_Table_Reads$Filter<- replace(QC_Table_Reads$Filter, QC_Table_Reads$Filter == "raw", "1_raw")
QC_Table_Reads$Filter<- replace(QC_Table_Reads$Filter, QC_Table_Reads$Filter == "dust", "2_dust")
QC_Table_Reads$Filter<- replace(QC_Table_Reads$Filter, QC_Table_Reads$Filter == "qvtrim", "3_qvtrim")
QC_Table_Reads$Filter<- replace(QC_Table_Reads$Filter, QC_Table_Reads$Filter == "seq_adapt_trim", "4_seq_adapt_trim")
QC_Table_Reads$Filter<- replace(QC_Table_Reads$Filter, QC_Table_Reads$Filter == "primer_trim", "5_primer_trim")
QC_Table_Reads$Filter<- replace(QC_Table_Reads$Filter, QC_Table_Reads$Filter == "merged", "6_merged")

summary(QC_Table_Reads)

#cutting table into lists of N samples each.
SplitTable<- split_table(QC_Table_Reads)




pdf(OutputFname, width=11, height=9.5) #open PDF writer


p <- plot.new()
#p+text(x=.50,.50, cex=.5, c(paste("Reads_Summary ", "**", TableNames[i], "**", "\n", sep="",
#                                  "\n",
#                                  summary(TableMerge[,i]),
#                                  "\n",
#                                  "\n",
#                                  "Remaining Samples: ")))
#
#print(p)

#Reads in a list of split tables, melts to long form, plots, then
#saves as a barplot, incrementing the output name of the plot

for(i in 1:length(SplitTable)){
  Tm <- melt_TableMerge(SplitTable[i])
  Ta <-plot_table(Tm, TableMaxReads)
  print(Ta) #plots to PDF, each on own page
}

dev.off()

cat("Done.\n");

print(warnings());
quit()
