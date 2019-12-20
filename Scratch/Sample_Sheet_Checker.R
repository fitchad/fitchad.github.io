
library(dplyr)
library(hash)



###### Loading Data ####################################################

InputSampleSheet <- read.csv("Desktop/sf_QIIME-SHARED/Temp/20191206_Medbio_updated3.csv", sep = ",", colClasses = "character")

#Looking for [Data] header (returns integer)
DataHeader <- grep("[Data]", InputSampleSheet$X.Header, fixed=TRUE)

#Subsetting to Samples only, ie everything after the [Data] header
SamplesOnly <- InputSampleSheet[-(1:DataHeader),]
row.names(SamplesOnly)<- NULL
colnames(SamplesOnly)<- NULL

#Making the first row of the subsetted df the header row for the df
colnames(SamplesOnly)<-as.character(unlist(SamplesOnly[1,]))
SamplesOnly<- SamplesOnly[-1, ]
row.names(SamplesOnly)<- NULL # resetting the row numbers

#################################################################################

##############################
######### Functions ##########
##############################


#dupDict=list()
check_duplicates <- function(dfCol){

  dupVec<-duplicated(dfCol)
  dupDict = list()
  for (i in 1:length(dupVec)){
    if (dupVec[i]=="TRUE"){
      if(dfCol[[i]] %in% names(dupDict)){
        
        next
      } else{
      dupDict[dfCol[i]] = i
      }
    }
    for (j in 1:length(dfCol)){
      if (dfCol[j] %in% names(dupDict)){ 
          
        dupDict[[dfCol[j]]] = c(dupDict[[dfCol[j]]], j)
      }

       
     }
      
    } 
return(dupDict)
}     



testDict<-check_duplicates(SamplesOnly$Sample_ID)
testDict2<-check_duplicates(SamplesOnly$Sample_Well)
