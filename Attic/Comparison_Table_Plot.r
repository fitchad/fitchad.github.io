#!/usr/bin/env Rscript

#Last Edit : 9/17/18 4pm

library("ggplot2");
library("getopt");
library("reshape2");

options(useFancyQuotes = F);


#TO DO:
#1. output - get directory


########################
###### Parameters ######
########################


params = c(
  "comptable", "c", 1, "character",
  "outputfilename", "o", 2, "character",
  "samplesperplot", "s", 3, "integer"
);

opt=getopt(spec = matrix(params, ncol=4, byrow=TRUE), debug=FALSE);
script_name=unlist(strsplit(commandArgs(FALSE) [4], "=")[1])[2];

usage = paste(
  "\nUsage:\n", script_name, "\n",
  "\n",
  "-c <comptable>\n",
  "\n",
  "[-o outputfilename]\n",
  "\n",
  "[-s samplesperplot]\n",
  "\n",
  "This script will take in a read comparison .csv file","\n",
  "and generate bar plots for each sample", "\n",
  "/n",
  "Plots are split by a user defined samples size, or default of 50 per plot",
  "\n",
  "\n",
  "Plots are saved in the same directory as the comparison table\n",
  "\n",
  "\n"
  
);

if(!length(opt$comptable)){
  cat(usage);
  q(status=-1);
}


if(!length(opt$outputfilename)){
  OutputFname=basename(opt$comptable)
  OutputFname=gsub(".csv", "", OutputFname);
}else{
  OutputFname=opt$outputfilename;
}

OutputFname=paste(OutputFname, ".ReadsComparisonBarplot.jpg", sep="");

if(!length(opt$samplesperplot)){
  SamplesPerPlot = 50;
}else{
  SamplesPerPlot = opt$samplesperplot;
}


CompTableFname <- opt$comptable

cat("CompTableFname: ", CompTableFname, "\n", sep="");
cat ("Output Filename Root: ", OutputFname, "\n", sep="");

###################
#### Functions ####
###################

split_table <- function(table){
  if(nrow(table)>SamplesPerPlot){
  cat ("
Table has greater than", SamplesPerPlot, "samples, splitting into chunks
       \n")
  tablecomp.split <- split(table, (as.numeric(rownames(table))-1) %/% SamplesPerPlot)
  }
  else{
    cat("
Less than", SamplesPerPlot, "samples, plotting all on a single plot
        \n")
    tablecomp.split <- split(table, (as.numeric(rownames(table))-1) %/% SamplesPerPlot)
  }
  return (tablecomp.split);
  
}

load_comptable=function(fname){
  comp_table=read.csv(fname);
  return(comp_table);
}

melt_comptable<-function(table){
  df.long<- melt(table)
  return(df.long)
  
}
plot_table<- function(table){
  plotted_table <- ggplot(table, aes(table$SampleID, value, fill=variable, width=0.75))+
    geom_bar(stat="identity",position="dodge", width = 0.5)+
    theme(axis.text.x=element_text(angle = 90, size=15)) + 
    theme(axis.text.y=element_text(size=15)) +
    theme(axis.title.x=element_text(size=20)) +
    theme(axis.title.y=element_text(size=20)) +
    theme(legend.text =element_text(size=18)) +
    labs(title="", x="SampleID", y="Reads Count")
  return(plotted_table);
  
}

save_plot<- function(table, number){

  name<- paste(c(number,OutputFname), collapse = "_")
  ggsave(name, path=dirname(opt$comptable), plot=table, width=15, height=15, units =c("in"))
  
}
##################################
#### Main Program starts here ####
##################################

cat ("Loading Comp Table....\n", "\n")

CompTable <- load_comptable(CompTableFname)
SampleNames <- rownames(CompTable)
TableNames <- colnames(CompTable)

### Reads Summary Stats ###
for (i in 2:ncol(CompTable)){
  cat("Reads_Summary ", "**", TableNames[i], "**", "\n", sep="")
  print(summary(CompTable[,i]))
  count<- length(which(CompTable[,i]==0))
  cat ("Number of Zero Count Samples:", count, "\n", "\n")
}



#ordering by sampleID prior to split
CompTable<-CompTable[order(CompTable$SampleID),]

#setting rownames to Null, so that the numeric row names at import are
#reset prior to split. 
rownames(CompTable) <- NULL

#cutting table into lists of 50 samples each.
SplitTable<- split_table(CompTable)


#Reads in a list of split tables, melts to long form, plots, then
#saves as a barplot, incrementing the output name of the plot

for(i in 1:length(SplitTable)){
  Tm <- melt_comptable(SplitTable[i])
  Ta <-plot_table(Tm)
  save_plot(Ta,i)
  
}

cat("Done.\n");

print(warnings());
quit()
