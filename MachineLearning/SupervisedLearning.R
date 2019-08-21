#Supervised Learning Code


#Goal: code will take in csv data, split into test and training sets, and run 
#several machine learning algorithms. 

#Author: Adam Fitch
##################
## Packages ######
##################

library(MASS) # for the example dataset 
#library(plyr) # for recoding data
library(ROCR) # for plotting roc
library(e1071) # for nb and SVM
library(rpart) # for decision tree
library(ada) # for adaboost
#library(car) ## needed to recode variables
library(class) # for knn


set.seed(21718)
#################################
### Data Import and Splitting ###
#################################

#IrisData<-as.data.frame(iris)
#summary(IrisData)
#classification.col <- 5
#data.col <- c(1,2,3,4)
#dataset<- IrisData



#data.url ='https://www.biz.uiowa.edu/faculty/jledolter/DataMining'
data.url <- 'http://web.stanford.edu/class/archive/cs/cs109/cs109.1166/stuff'
data.file <- file.path(data.url, 'titanic.csv')
#data.file <- file.path(data.url, 'germancredit.csv')
dataset <- read.csv(data.file, header = TRUE, sep = ',')
dataset$Sex<-gsub(c('female'), c(0), dataset$Sex)
dataset$Sex<-gsub(c('male'), c(1), dataset$Sex)
dataset$Sex<- as.numeric(dataset$Sex)

classification.col<- 1
#data.col<- c(3,6,9,12,14,17,19)
data.col <- c(2,4,5,6,7)


row.count <- nrow(dataset)
train.count <- floor(nrow(dataset)*0.6)
#train.rows<-dataset[sample(1:nrow(dataset), train.count,
#replace=FALSE),]
train.rows<-sample.int(n=nrow(dataset),size=train.count,replace=F)
train.data<-dataset[train.rows,]
test.data<-dataset[-train.rows,]
train.class <- train.data[,classification.col]
test.class<- test.data[,classification.col]
train.data<- train.data[,data.col]
test.data<- test.data[,data.col]
train.data.all<- cbind(train.class,train.data)

########################
### Functions ##########
########################

# will take in a 2 column probability output [col 1 contains probability of 0 outcome, col 2 probability of 1 outcome]
# and convert to a single column of 0,1
convert_output<- function (col_probability){
  len <- length(col_probability)/2
  predictions <- vector(mode="numeric", length=len)
  for (i in 1:len){
    if (col_probability[i,1] > col_probability[i,2]){
      predictions[i]<-0
    }else{
      predictions[i]<-1
      
    }
    
  }
  return (predictions)
  
}


rocr_plot<- function(predictions_output, test.class){
  pred<-prediction(as.integer(predictions_output), test.class)
  perf <- performance(pred, "tpr","fpr")
  plot(perf)
  
  
}


performance_metrics <- function(confusion_matrix){
  #Accuracy - (TP + TN)/(TP+TN+FP+FN)
  Accuracy<-(confusion_matrix[1,1]+confusion_matrix[2,2])/sum(confusion_matrix[,1]+confusion_matrix[,2])
  cat(Accuracy)
  #Precision - (TP) / (TP+FP)
  Precision<-confusion_matrix[2,2]/(confusion_matrix[2,2]+confusion_matrix[1,2])
  cat(Precision)
  #Recall/Sensitivity - TP/(TP+FN)
  Sensitivity<- confusion_matrix[2,2]/(confusion_matrix[2,2]+confusion_matrix[2,1])
  cat(Sensitivity)
  #Specificity - TN / (TN+FP)
  Specificity<- confusion_matrix[1,1]/(confusion_matrix[1,1]+confusion_matrix[1,2])
  cat(Specificity)
}



########################
#### Classifiers #######
########################


####  knn #######
#################
predict_knn<- knn(train.data, test.data, k=3, cl=train.class)
predict_knn
confusion_matrix_knn <- table(test.class,predict_knn)

#predictions_knn <- as.numeric(predict_knn)

###  Naive Bayes ###
####################

model_nb <- naiveBayes(train.data, train.class)
predict_nb <- predict(model_nb, test.data, type="raw")

#converting output of function to a vector of 0,1. 
predictions_nb <- convert_output(predict_nb)

confusion_matrix_nb <- table(test.class,predictions_nb)



## svm ##
#########

svm_tune <- tune(svm, train.x=train.data, train.y=train.class,
             ranges = list(gamma = 2^(-1:1), cost = 2^(2:4)),
            tunecontrol = tune.control(sampling = "boot"))
 #Default~.,
summary(svm_tune)

gamma = svm_tune[['best.parameters']]$gamma
cost = svm_tune[['best.parameters']]$cost

model_svm = svm(x=train.data, y=train.class, probability=T, kernel="radial", gamma=gamma, cost=cost)

predict_svm <- predict(model_svm, test.data)
predict_svm
predictions_svm <- as.numeric(predict_svm>0.5)
confusion_matrix_svm <- table(test.class,predictions_svm)



### Decisions Trees ###
######################

model_dtree <- rpart(formula=train.class~., method="class", data=train.data.all)
print(summary(model_dtree))

predict_dtree<-predict(model_dtree, newdata=test.data)

predictions_dtree<- convert_output(predict_dtree)

confusion_matrix_dtree <- table(test.class,predictions_dtree)


### ada boost #####
###################

model_adaboost <- ada(x=train.data, y=train.class)
predict_adaboost<-predict(model_adaboost, newdata = test.data)
confusion_matrix_adaboost <- table(test.class, predict_adaboost)



confusion_matrix_knn
confusion_matrix_nb
confusion_matrix_svm
confusion_matrix_dtree
confusion_matrix_adaboost



#results<- data.frame(predict_nb, test.class)

# ROCR #
pred<- prediction(as.integer(predict_knn), test.class)
perf <- performance(pred, "tpr","fpr")
plot(perf) 

pred<- prediction(as.integer(predictions_nb), test.class)
perf <- performance(pred, "tpr","fpr")
plot(perf) 

pred<- prediction(as.integer(predictions_svm), test.class)
perf <- performance(pred, "tpr","fpr")
plot(perf) 

pred<- prediction(as.integer(predictions_dtree), test.class)
perf <- performance(pred, "tpr","fpr")
plot(perf) 

pred<- prediction(as.integer(predict_adaboost), test.class)
perf <- performance(pred, "tpr","fpr")
plot(perf)

rocr_plot(predict_knn, test.class)
rocr_plot(predict_adaboost, test.class)
