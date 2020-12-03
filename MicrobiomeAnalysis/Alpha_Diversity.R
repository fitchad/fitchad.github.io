#!/usr/bin/env Rscript

#Last Edit : 10/5/20 1pm

#Author: Adam Fitch

library("ggplot2");
library("vegan")
library("getopt");
library("reshape2");
library("plyr");

options(useFancyQuotes = F);


#TO DO:
#1. output - get directory
#. dfdfdff

########################
###### Parameters ######
########################


params = c(
  "summarytable1", "i", 1, "character",
  "factorsfile", "m", 2, "character",
  "diversity", "d", 3, "character",
  "outputfilename", "o", 4, "character",
  "columnstoretain", "C", 5, "list"
  
);



opt=getopt(spec = matrix(params, ncol=4, byrow=TRUE), debug=FALSE);
script_name=unlist(strsplit(commandArgs(FALSE) [4], "=")[1])[2];

usage = paste(
  "\nUsage:\n", script_name, "\n",
  "\n",
  "-i <summarytable1>\n",
  "\n",
  "-m <factorsfile>\n",
  "\n",
  "[-d diversity]\n",
  "\n",
  "[-o outputfilename]\n",
  "\n",
  "[-C metadata_columns_to_retain] (should be written as 4,5,6,7)\n",
  "\n",
  "This script will take in a summary table, factor file ",
  "\n",
  "and generate box plots for various alpha diversity metrics", 
  "\n",
  "\n",
  "A single metric can be specified, or the default of all metrics will be used",
  "\n",
  "Metrics are 'Shannon', 'Simpson', or 'inv'",
  "\n",
  "\n",
  "Columns are specifice by their numeric value",
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

if(!length(opt$factorsfile)){
  cat(usage);
  q(status=-1);
}else{
  FactorsFname<- opt$factorsfile
}


if(!length(opt$diversity)){
  DiversityM = "All"
}else{
  DiversityM=opt$diversity
}


if(!length(opt$outputfilename)){
  OutputFname=tools::file_path_sans_ext(opt$summarytable1)
  OutputFname=gsub(".csv", "", OutputFname);
}else{
  OutputFname=opt$outputfilename;
}

OutputFname=paste(OutputFname, ".alpha.diversity.PDF", sep="");


if(!length(opt$columnstoretain)){
  ColToRetain=NULL
}else{
  ColToRetain=opt$columnstoretain;
  ColToRetain=strsplit(ColToRetain, ",")
  ColToRetain=as.numeric(unlist(ColToRetain[[1]]))
}


cat("\n")
cat("Summary Table: ", SumTable1Fname, "\n", sep="");
cat("\n")
cat("Factors File: ", FactorsFname, "\n", sep="");
cat("\n")
if (!is.null(DiversityM)){
  cat("Alpha Diversity Metrics: ", DiversityM, "\n", sep="");
}
cat("\n")
cat ("Output Filename: ", OutputFname, "\n", sep="")
cat("\n")


######################
#### Loading Data ####
######################

inmat1=as.data.frame(read.table(SumTable1Fname, sep="\t", header=TRUE, row.names=1, check.names=FALSE, quote=NULL))
#inmat1_no_totals<-as.data.frame(inmat1[,2:ncol(inmat1), drop=FALSE]) #retains row names

#inmat2=as.data.frame(read.table(FactorsFname, sep="\t", header=TRUE, row.names=1, check.names=FALSE, quote=NULL))
#CountsMat2<-as.data.frame(inmat2[,1, drop=FALSE]) #retains row names

#Load factors
load_factors=function(fname){
  factors=as.data.frame(read.delim(fname, header=TRUE, row.names=1, check.names=FALSE, sep = "\t"));
  if(!is.null(ColToRetain)){
    factors=factors[c(ColToRetain-1)]
  }
  return(factors);
  
}

FactorsFile<-load_factors(FactorsFname)
NumberColumnsMeta <- ncol(FactorsFile)

cat("Retaining Factors Columns:", "\n")
print(colnames(FactorsFile))
cat("\n")

summarytable_sample_names=rownames(inmat1)
factor_sample_names=rownames(FactorsFile)

############### From KL Permanova.r script #####################################
# Confirm/Reconcile that the samples in the matrix and factors file match
cat("SummaryTable Samples:\n");
print(summarytable_sample_names);
cat("\n");
cat("Factor Samples:\n");
print(factor_sample_names);

num_factor_samples=length(factor_sample_names);
num_summarytable_samples=length(summarytable_sample_names);

common_sample_names=intersect(summarytable_sample_names, factor_sample_names);
num_common_samples=length(common_sample_names);
if(num_common_samples < num_summarytable_samples || num_common_samples < num_factor_samples){
        cat("\n");
        cat("*** Warning: The number of samples in factors file does not match those in your distance\n");
        cat("Taking intersection (common) sample IDs between both.\n");
        cat("Please confirm this is what you want.\n");
        cat("\tNum SummaryTable Samples: ", num_summarytable_samples, "\n");
       cat("\tNum Factor  Samples: ", num_factor_samples, "\n");
        cat("\tNum Common  Samples: ", num_common_samples, "\n");
        cat("\n");
}


# Set the working distance matrix to the same order
inmat1=inmat1[common_sample_names, , drop=F];
inmat1_no_totals<-as.data.frame(inmat1[,2:ncol(inmat1), drop=FALSE]) #retains row names

FactorsFile=FactorsFile[common_sample_names, , drop=F];

print(FactorsFile)
#print(inmat1_no_totals)


##########################
### Diversity Calcs ######
##########################

if (DiversityM =="All"){
  notsure <- diversity(inmat1_no_totals)
  shannon_div <- diversity(inmat1_no_totals, index="shannon", MARGIN=1, base=exp(1))
  simpson_div<- diversity(inmat1_no_totals, index="simpson")
  inv_simpson<- diversity(inmat1_no_totals, index="inv")
  unbias_simpson<- rarefy(inmat1_no_totals, 2) -1
  #fisher_alpha<- fisher.alpha(inmat1_no_totals)
  spec_richness<- specnumber(inmat1_no_totals)
  Pielous_eveness<- notsure/log(spec_richness)
  s_d <- cbind(shannon_div, simpson_div, inv_simpson, unbias_simpson, spec_richness, Pielous_eveness) #binding all 3 into one df
  
  
}else if(DiversityM =="Shannon"){
    shannon_div <- diversity(inmat1_no_totals, index="shannon", MARGIN=1, base=exp(1))
    s_d <- cbind(shannon_div)
}else if (DiversityM =="Simpson"){
  simpson_div<- diversity(inmat1_no_totals, index="simpson")
  s_d<- cbind(simpson_div)
}else if (DiversityM =="inv"){
    inv_simpson<- diversity(inmat1_no_totals, index="inv")
    s_d<- cbind(inv_simpson)
}


#s_d <- cbind(row.names(s_d), s_d) #making a column of rownames so I can properly label column



#######################
#### Functions ########
#######################
plot_table<- function(df, X,Y){
  #f_c <- as.character(colnames(df[X]))
  plotted_table <- ggplot(df, aes(x=df[,X], y=df[,Y], color=df[,X]))+
    geom_boxplot(outlier.shape=NA, aes(alpha=0.5, fill=df[,X]))+
    geom_jitter(position=position_jitter(0.1), shape=1, color="black", size=2)+
#    scale_fill_manual(value = c("blue", "red"))+
    labs(title="", x=colnames(df[X]), y=colnames(df[Y]),color=colnames(df[X]))
#	guides(fill=guide_legend("Sort_Status")
    
  return(plotted_table);
  
}


############################################
##### Combining Diversity and Factors #####
############################################



s_d<- as.data.frame(s_d)

merged_df<- merge.data.frame(s_d, FactorsFile, by="row.names")
names(merged_df)[1]<- "SampleID" #Changing "Row.names" to "SampleID".
head(merged_df)
ncol(merged_df)

###############################
#### Plotting of Diversity ####
###############################


pdf(OutputFname, width=11, height=9.5) #open PDF writer



for(i in 2:(ncol(s_d)+1)){
  for (j in (2+ncol(s_d)):ncol(merged_df)){
    
  Ta <-plot_table(merged_df, j, i)
  #print(j) 
  print(Ta) #plots to PDF, each on own page
}
}
dev.off()




##Write out .csv of all alpha diversity metrics
OutputFname=tools::file_path_sans_ext(OutputFname)
OutputFname=paste(OutputFname, ".csv", sep="")
print(OutputFname)
write.csv(merged_df, file=OutputFname, row.names = FALSE)


cat("Done.\n");

print(warnings());
quit()


