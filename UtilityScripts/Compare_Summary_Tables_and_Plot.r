#!/usr/bin/env Rscript

#Author: Adam Fitch
#Last Edit : 6/5/19 1pm

library("ggplot2");
library("getopt");
library("reshape2");

options(useFancyQuotes = F);


#TO DO:
#1. output - get directory
#2. Add table summary to first page of PDF
#3. Add summary statistics? Mean / Median by category?
#5. Shorten name of tables, remove "summary_table.tsv"

########################
###### Parameters ######
########################


params = c(
  "summarytable1", "a", 1, "character",
  "summarytable2", "b", 2, "character",
  "summarytable3", "c", 3, "character",
  "outputfilename", "o", 4, "character",
  "samplesperplot", "s", 5, "integer",
  "columnlist", "l", 6, "list"
  
);

opt=getopt(spec = matrix(params, ncol=4, byrow=TRUE), debug=FALSE);
script_name=unlist(strsplit(commandArgs(FALSE) [4], "=")[1])[2];

usage = paste(
  "\nUsage:\n", script_name, "\n",
  "\n",
  "-a <summarytable1>\n",
  "\n",
  "-b <summarytable2>\n",
  "\n",
  "[-c summarytable3]\n",
  "\n",
  
  "[-l columnlist]\n",
  "\n",
  
  "[-o outputfilename]\n",
  "\n",
  "[-s samplesperplot]\n",
  "\n",
  "This script will take in a up to 3 summary tables","\n",
  "and generate bar plots for each sample per table", "\n",
  "\n",
  "The script can also generically plot values from different .tsv files against each other\n",
  "by defining a list of columns, assuming that each .tsv has the same sampleIDs in the first column\n",
  "\n",
  "Plots are split by a user defined samples size, or default of 50 per plot\n",
  "\n",
  "When using the -l to specify a list of columns enter as a quoted string, eg '1,6,4'\n",
  "with the order as 'Table1,Table2,Table3', eg Table1$1,Table2$6,Table3$4 will be compared\n",
  "Column number is calculated without including the first column containing the sampleIDs\n",
  "Default values for the column numbers is 1, corresponding to the totals column of a summary table\n",
  "\n",
  "Plots are saved in the same directory as the comparison table",
  "\n",
  "\n"
  
);

if(!length(opt$summarytable1)){
  cat(usage);
  q(status=-1);
}else{
  SumTable1Fname <- opt$summarytable1
}

if(!length(opt$summarytable2)){
  cat(usage);
  q(status=-1);
}else{
  SumTable2Fname<- opt$summarytable2
}


if(!length(opt$summarytable3)){
  SumTable3Fname=NULL
}else{
  SumTable3Fname=opt$summarytable3
}


if(!length(opt$outputfilename)){
  OutputFname=basename(opt$summarytable1)
  OutputFname=gsub(".csv", "", OutputFname);
}else{
  OutputFname=opt$outputfilename;
}

OutputFnameCSV=paste(OutputFname, ".ReadsComparison.csv", sep="")
OutputFname=paste(OutputFname, ".ReadsComparisonBarplot.pdf", sep="");

if(!length(opt$columnlist)){
  ColumnList = "1,1,1";
}else{
  ColumnList = opt$columnlist;
}

columnnameslist = strsplit(ColumnList,",")[[1]];


  

if(!length(opt$samplesperplot)){
  SamplesPerPlot = 50;
}else{
  SamplesPerPlot = opt$samplesperplot;
}




cat("\n")
cat("SumTable1Fname: ", SumTable1Fname, "\n", sep="");
cat("SumTable2Fname: ", SumTable2Fname, "\n", sep="");
if (!is.null(SumTable3Fname)){
  cat("SumTable3Fname: ", SumTable3Fname, "\n", sep="");
}
cat("\n")
cat ("Output Filename Root: ", OutputFname, "\n", sep="")
cat("\n")


########################
###### Functions #######
########################


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

melt_TableMerge<-function(table){
  df.long<- melt(table)
  #df.long<- df.long[,1:3]
  return(df.long)
  
}
plot_table<- function(table, yAxisLimit){
  plotted_table <- ggplot(table, aes(x=as.character(SampleID), value, fill=variable, width=0.75))+
    geom_bar(stat="identity",position="dodge", width = 0.5)+
    ylim(0,yAxisLimit)+
    theme(axis.text.x=element_text(angle = 90, size=15, vjust=0.5, hjust=1)) + 
    theme(axis.text.y=element_text(size=15)) +
    theme(axis.title.x=element_text(size=20)) +
    theme(axis.title.y=element_text(size=20)) +
    theme(legend.text =element_text(size=15)) +
    labs(title="", x="SampleID", y="Reads Count", fill="Table Name") +
    theme(legend.position = "bottom")+ theme(legend.direction = "vertical")
    
  return(plotted_table);
  
}

plot_bar <- function(table){
  sum_500<- sum(table$Total > 500)
  sum_1000<- sum(table$Total > 1000)
  sum_3000<- sum(table$Total > 3000)
  sum_5000<- sum(table$Total > 5000)
  sum_10000<- sum(table$Total > 10000)
  sum_total<-rbind(sum_500, sum_1000, sum_3000, sum_5000, sum_10000)
  #print(sum_total)
  total_counts<- c("500","1000","3000","5000","10000+")
  sum_table_total <- data.frame(names=total_counts, sum_total)

  plotted_table<- ggplot(sum_table_total, aes(names, sum_total), xlab="Read Counts", ylab="Sample Count", ylim=c(0,nrow(table)))+
    geom_col()+
    scale_x_discrete(limits=total_counts)+
    labs(x="Read Counts", y="Sample Count")
  
  
  
  return(plotted_table)
}

plot_text=function(strings){
  
  num_lines=length(strings);
  top=max(as.integer(num_lines), 52);
  text_size=.75
  plot(0,0, xlim=c(0,top), ylim=c(0,top), type="n",  xaxt="n", yaxt="n",
       xlab="", ylab="", bty="n", oma=c(1,1,1,1), mar=c(0,0,0,0)
  );
  
  
  
  for(i in 1:num_lines){
    #cat(strings[i], "\n", sep="");
    strings[i]=gsub("\t", "", strings[i]);
    text(0, top-i, strings[i], pos=4, cex=text_size);
  }
  
  
}

##### Currently unused ######
save_plot<- function(table, number){
  name<- paste(c(number,OutputFname), collapse = "_")
  ggsave(name, path=dirname(opt$summarytable1), plot=table, width=15, height=15, units =c("in"))
  
}



######################
#### Loading Data ####
######################

inmat1=as.data.frame(read.table(SumTable1Fname, sep="\t", header=TRUE, row.names=1, check.names=FALSE, quote=NULL))
CountsMat1<-as.data.frame(inmat1[,as.numeric(columnnameslist[1]), drop=FALSE]) #retains row names

inmat2=as.data.frame(read.table(SumTable2Fname, sep="\t", header=TRUE, row.names=1, check.names=FALSE, quote=NULL))
CountsMat2<-as.data.frame(inmat2[,as.numeric(columnnameslist[2]), drop=FALSE]) #retains row names

if (!is.null(SumTable3Fname)){
inmat3=as.data.frame(read.table(SumTable3Fname, sep="\t", header=TRUE, row.names=1, check.names=FALSE, quote=NULL))
CountsMat3<-as.data.frame(inmat3[,as.numeric(columnnameslist[3]), drop=FALSE]) #retains row names
}


##################
## Main Program ##
##################


if (basename(SumTable1Fname) == basename(SumTable2Fname)){
  cat ("Summary Tables have the same filename. Will append digit.")
  cat ("\n")
  cat ("################################################")
  cat ("\n")
  cat (SumTable1Fname)
  SumTable1Fname=paste(SumTable1Fname, ".1", sep="")
  cat ("\n")
  cat ( "is now ")
  cat ("\n")
  cat(basename(SumTable1Fname))
  cat ("\n")
  cat ("################################################")
  cat ("\n")
  cat (SumTable2Fname)
  cat ("\n")
  cat ( "is now ")
  cat ("\n")
  SumTable2Fname=paste(SumTable2Fname, ".2", sep="")

  cat (basename(SumTable2Fname))
  cat ("\n")
  cat ("###############################################")
  cat ("\n")
  cat ("\n")
  cat ("\n")
       
}




#Merging Summary Table Reads and Metadata File
TableMerge<- merge(CountsMat1, CountsMat2, all=T, by="row.names")
if(!is.null(SumTable3Fname)){
  rownames(TableMerge)<- TableMerge$Row.names
TableMerge<- TableMerge[,2:3]

}else{colnames(TableMerge)<- c("SampleID", basename(SumTable1Fname), basename(SumTable2Fname))
}

#Merging with Table 3, if it exists
if(!is.null(SumTable3Fname)){
TableMerge<- merge(TableMerge, CountsMat3, all=T, by ="row.names")
colnames(TableMerge)<- c("SampleID", basename(SumTable1Fname), basename(SumTable2Fname), basename(SumTable3Fname))
}

#Reassinging NAs to 0 (ie samples not present in one table or another)
TableMerge[is.na(TableMerge)] <- 0

TableNames <- colnames(TableMerge)
TableMelt <- melt_TableMerge(TableMerge)
TableMaxReads <- max(TableMelt$value) # Getting max read value to keep ylim consistent across plots

### Writing CSV of reads comparison
write.csv(TableMerge, file=OutputFnameCSV, quote=FALSE, row.names = FALSE)

### Reads Summary Stats ###
for (i in 2:ncol(TableMerge)){
  cat("Reads_Summary ", "**", TableNames[i], "**", "\n", sep="")
  print(summary(TableMerge[,i]))
  count<- length(which(TableMerge[,i]==0))
  cat ("Number of Zero Count Samples:", count, "\n", "\n")
}


#ordering by sampleID prior to split
TableMerge<-TableMerge[order(TableMerge$SampleID),]

#setting rownames to Null, so that the numeric row names at import are
#reset prior to split. 
rownames(TableMerge) <- NULL

#cutting table into lists of 50 samples each.
SplitTable<- split_table(TableMerge)


pdf(OutputFname, width=11, height=9.5) #open PDF writer

par(mfrow=c(2,2))



for (i in 2:ncol(TableMerge)){
  #cat("Reads_Summary ", "**", TableNames[i], "**", "\n", sep="")
  count<- length(which(TableMerge[,i]==0))
  plot_text(c(
    #paste(TableNames[i]),
    paste("Reads Summary **", colnames(TableMerge[i]), " **"),
    paste("Number of zero count samples: ", count),
    summary(TableMerge[i])))


}


#Reads in a list of split tables, melts to long form, plots, then
#saves as a barplot, incrementing the output name of the plot

#LengthSplit <- length(SplitTable)
#PlotList <- vector("list", LengthSplit)
 
for(i in 1:length(SplitTable)){
  Tm <- melt_TableMerge(SplitTable[i])
  Ta <-plot_table(Tm, TableMaxReads)
  #save_plot(Ta,i)
  #PlotList<-c(Ta, i)
  print(Ta) #plots to PDF, each on own page
}


S1<- plot_bar(CountsMat1)
S2<- plot_bar(CountsMat2)

S1 + labs(title = basename(SumTable1Fname))
S2 + labs(title = basename(SumTable2Fname))


dev.off()



cat("Done.\n");

print(warnings());
quit()

