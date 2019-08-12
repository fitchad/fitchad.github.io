
library("ggplot2");
library("getopt");
library("reshape2");

##Reading data
QC_Table<-read.csv("~/Desktop/sf_QIIME-SHARED/Temp/0169_Deton_QC_25_Report.tsv", sep ="\t")
##Trimming table to sampleID / read type / filter used / reads count
QC_Table_Reads <- QC_Table[,1:4]
Paired_vect <- QC_Table_Reads$Read == "paired"
Read_Filter <- as.vector(paste(QC_Table_Reads$Read, QC_Table_Reads$Filter, sep="_"))


##dividing paired merged reads by 2 as this set is double counted
for (i in 1:length(Paired_vect)){
  if (Paired_vect[i]=="TRUE"){
    QC_Table_Reads[i,]$NumRecords <- QC_Table_Reads[i,]$NumRecords/2}
}

##Modifying QC table. Adding a combined Read_Filter column, and renaming the Filter column
##so that it is ordered correctly in the facet grid

QC_Table_Reads<- cbind(QC_Table_Reads, Read_Filter)
#QC_Table_Reads<- subset(QC_Table_Reads, select= -c(Read,Filter))
QC_Table_Reads$Filter <- as.character(QC_Table_Reads$Filter)
QC_Table_Reads$Filter<- replace(QC_Table_Reads$Filter, QC_Table_Reads$Filter == "raw", "1_raw")
QC_Table_Reads$Filter<- replace(QC_Table_Reads$Filter, QC_Table_Reads$Filter == "dust", "2_dust")
QC_Table_Reads$Filter<- replace(QC_Table_Reads$Filter, QC_Table_Reads$Filter == "qvtrim", "3_qvtrim")
QC_Table_Reads$Filter<- replace(QC_Table_Reads$Filter, QC_Table_Reads$Filter == "seq_adapt_trim", "4_seq_adapt_trim")
QC_Table_Reads$Filter<- replace(QC_Table_Reads$Filter, QC_Table_Reads$Filter == "primer_trim", "5_primer_trim")
QC_Table_Reads$Filter<- replace(QC_Table_Reads$Filter, QC_Table_Reads$Filter == "merged", "6_merged")


#QC_Table_Reads$Filter<- replace(QC_Table_Reads$Filter, c("raw", "dust","qvtrim", "seq_adapt_trim", "primer_trim", "merged"), c("1_raw", "2_dust", "3_qvtrim", "4_seq_adapt_trim", "5_primer_trim", "6_merged"))

QC_Table.long<- melt(QC_Table_Reads)


##Plotting Table
plotted_table <- ggplot(QC_Table.long, aes(x=as.character(X..Name), value, fill=Read_Filter, width=0.75))+
  geom_bar(stat="identity",position="dodge", width = 0.5)+
  facet_grid(rows=vars(Filter)) +
  theme(axis.text.x=element_text(angle =45, size=12, hjust=1, vjust=1))+
  labs(title="", x="SampleID", y="Reads Count")
plotted_table
