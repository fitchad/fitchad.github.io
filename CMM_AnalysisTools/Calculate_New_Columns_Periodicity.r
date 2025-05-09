#!/usr/bin/env Rscript

###############################################################################

library('getopt');
options(useFancyQuotes=F);
options(width=120);

params=c(
	"input", "i", 1, "character",
	"formulas", "f", 1, "character",
	"output", "o", 1, "character"
);

opt=getopt(spec=matrix(params, ncol=4, byrow=TRUE), debug=FALSE);
script_name=unlist(strsplit(commandArgs(FALSE)[4],"=")[1])[2];

usage = paste(
	"\nUsage:\n", script_name, "\n",
	"	-i <input tab-separated column data file>\n",
	"	-f <formulas file>\n",
	"	-o <output tab_separated column data file>\n",
	"\n",
	"This script will read in a metadata file\n",
	"and run through the list of formulas to add\n",
	"derived data to the table.\n",
	"\n",
	"Example formulas file entries:\n",
	"	fev1.over.fvc=bdfev1/bdfvc\n",
	"	age=(dob-baldat)/365\n",
	"	smoke=(env.cigrete==\"Yes\" || env.cigar==\"Yes\" || env.pipe==\"Yes\")\n",
	"	delete env.cigrete\n",
	"	delete env.cigar\n",
	"	delete env.pipe\n",
	"	good.ids=!is.na(subj_ids)\n",
	"	keep good.ids\n",
	"	make_key subj_ids\n",
	"\n",
	"Additional columns will be added to the end\n",
	"of the existing columns.  If the formula line is \"delete\"\n",
	"Then the column will be deleted.\n",
	"\n",
	"Rows/Samples can be conditionally kept/removed by using\n",
	"the \"keep\" command.  First create/identify a variable/column that is T/F\n",
	"then specify that variable as parameter for the keep command.  Rows that\n",
	"are F will be excluded.\n",
	"\n",
	"A column can be moved to the first column position perhaps making it a\n",
	"primary key or sample id for the matrix with the \"make_key\" command.\n",
	"\n",
	"In addition, the following non-standard R functions have been implemented:\n",
	"\n",
	"	bin(x, range_name, breaks): \n",
	"		This will assign the range name to the values that fall between and outside the breaks\n",
	"		Note that you will have 1 more range name, than breaks.\n",
	"	  example:\n",
	"	    tertiles=bin(x, c(\"low\", \"medium\", \"high\"), c(33,66))\n",
	"\n",	
	"	remap(x, key, value):  This will remap the keys in x to the corresponding values.\n",
	"	  example:\n",
	"	     gpa=remap(grade, c(\"A\", \"B\", \"C\", \"D\", \"E\"), c(4, 3, 2, 1, 0))\n",
	"\n",
	"	redefine_NA(x, value):  This will remap all the NAs in x to the the specified value.\n",
	"	  example:\n",
	"	     medication_usage_nona=redefine_NA(medication_usage, 0)\n",
	"\n",
	"	function.list(fun, list(x, y, ...), na.rm=T): This a generic function that will apply the 'fun' command\n",
	"		across the rows for each of the columns specified in the list.\n",
	"		If you don't do this, the function by itself will apply to the column, isntead of\n",
	"		between columns.\n",
	"\n",
	"	  Examples of Functions that need this to work properly:\n",
	"		min, max, sum, etc.\n",
	"\n",
	"	  Example Usage:\n",
	"	     max_long_weekend_smokes=function.list(max, list(saturday, sunday, monday)); \n",
	"\n",
	"\n",
	"	mask(x, bool_arr, mask_value): This will return the values in x masked with the values\n",
	"		in the mask_value.  The rows in bool_arr will be used as the mask condition.\n",
	"		This is useful for conditionally replacing specific values with a new value.\n",
	"\n",
	"\n",
	"	to.bool(x):  This will convert x to upper case and then to 0/1 so R won't treat them as factors:\n",
	"			FALSE / TRUE\n",
	"			F / T\n",
	"			NO / YES\n",
	"			OFF / ON\n",
	"		For other less commonly used boolean pairs, use the remap function.\n",
	"\n",
	"	String Manipulation Functions:\n",
	"		left/right will extract the number of characters from the string.\n",
	"		chop_left/chop_right will remove the number of characters from the string.\n",
	"		This is useful for managing subject or group identifiers that are not\n",
	"		highly duplicated.  Using the remap function may be more suitable for\n",
	"		for categorical levels.\n",
	"\n",
	"		str.left(x, n)\n",
	"		str.right(x, n)\n",
	"		str.chop_left(x, n)\n",
	"		str.chop_right(x, n)\n",
	"\n",
	"		str.split_keep(x, sep, keep_idx, join)\n",
	"			This will split x by sep, then only keep the keep_idx components\n",
	"			  then rejoin with the join character.  Useful for manipulating Sample IDs.\n",
	"			For example: \n",
	"			  str.split_keep(\"This.is.a.test\", \"\\\\.\", c(1,4), \".\");\n",
	"			Produces:\n",
	"			  \"This.test\"\n",
	"\n",
	"	Indexing:\n",
	"		index(start=1) will assign a number from start to number of rows.\n",
	"\n",
	"	days_from_date(x, format):\n",
	"		This will convert a date string, e.g. 2014-05-16, into the number of days\n",
	"		since Thursday, 1 1970.  If a date is before then, the number will be negative\n",
	"		The function is a wrapper for as.Date, so you can check to see what\n",	
	"		formats it can handle.  The value may not be useful by itself, but should\n",
	"		be used when calculating days between two events.  Make sure you specify\n",
	"		the format string. \n",
	"			For example: \n",
	"				\"%m/%d/%Y\" for mm/dd/yyyy\n",
	"				\"%Y-%m-%d\" for yyyy-mm-dd\n",
	"\n",
	"	offsets_by_group(values, ref, grouping)\n",
	"		This will compute the relative offsets starting from 0, for all the values\n",
	"		in the same group.  The group may be a subject ID and the values may be\n",
	"		a time/date value from the days_from_date function.\n",
	"\n",
	"		The ref variable may be left NULL, but if it is used, then the minimum\n",
	"		value from the reference will be used.\n",
	"			For example:\n",
	"			  visit_days=offsets_by_group(all_visits_dates, NULL, subject_id);\n",
	"			  event_days=offsets_by_group(event_dates, all_visits_dates, subject_id);\n",
	"\n",
	"	indices_by_group(values, grouping)\n",
	"		This will compute an index starting from 1, for all the values in the\n",
	"		same group.  The groups may be a subject ID and the values may be a time/date\n",
	"		value.  You can think of these as ordered visits.\n",
	"\n",
	"	num_to_str_id(numeric_id, prefix=\"s\")\n",
	"		This will convert the numeric id into a string.  By default, a prefix is prepended\n",
	"		to the number to make it a string.\n",
	"\n",
	"	set_LOQ(x, detection_limit_value, method)\n",
	"		This will reset the detection_limit value in the column to a new value.\n",
	"		For example, if the detection_limit value is 0 or -1, then that will be converted.\n",
	"		The goal is to differentiate detecton limit from NA (missing data)\n",
	"		Specify the methods:\n",
	"			zero:  set LOQ to 0\n",
	"			min_div10:  find min, then divide by 10\n",
	"			min_div02:  find min, then divide by 2\n",
	"			expected:  Assume X is normal, set LOQ to Exp[X: X<LOQ]\n",
	"\n",
	"\n",
	"For debugging you can also do:\n",
	"	print <variable name>\n",
	"	quit\n",
	"\n");

if(!length(opt$input) || !length(opt$formulas) || !length(opt$output)){
	cat(usage);
	q(status=-1);
}

InputFName=opt$input;
Formulas=opt$formulas;
OutputFName=opt$output;

cat("Input Filename: ", InputFName, "\n");
cat("Formulas: ", Formulas, "\n");
cat("Output Filename: ", OutputFName, "\n");

##############################################################################

load_factors=function(fname){
	factors=data.frame(read.table(fname,  header=TRUE, check.names=FALSE, as.is=T, comment.char="", quote="", sep="\t"));

	#print(factors);

	dimen=dim(factors);
	cat("Rows Loaded: ", dimen[1], "\n");
	cat("Cols Loaded: ", dimen[2], "\n");

	return(factors);
}

write_factors=function(fname, table){

	dimen=dim(factors);
	cat("Rows Exporting: ", dimen[1], "\n");
	cat("Cols Exporting: ", dimen[2], "\n");
	
	write.table(table, fname, quote=F, row.names=F, sep="\t");

}

load_commands=function(fname){
	commands=readLines(fname);	
	return(commands);
}

##############################################################################
# Additional Functions

bin=function(x, range_names, breaks){
	len=length(x);
	num_ranges=length(range_names);
	num_breaks=length(breaks);

	if(num_ranges!=(num_breaks+1)){
		cat("Error! Range names and breaks don't agree. (num_breaks + 1) = num_ranges\n");
		cat("Num Ranges: ", num_ranges, "\n");
		print(range_names);
		cat("Num Breaks: ", num_breaks, "\n");
		print(breaks);
		quit(-1);
	}

	if(!all(breaks==sort(breaks))){
		cat("Error! Your breaks are out of order.  Are your range names ok?\n");
		quit(-1);
	}

	new=character(len);
	for(i in 1:len){
		if(!is.na(x[i])){
			if(x[i]>=breaks[num_breaks]){
				ix=num_ranges;
			}else{
				ix=min(which(x[i]<breaks));
			}
			new[i]=range_names[ix];
		}else{
			new[i]=NA;
		}
	}
	print(new);
	return(new);
}


remap=function(x, key, value, leave_unmapped_alone=T){

	len=length(x);
	if(length(key)!=length(value)){
		cat("Error!  Key/Value lengths are not the same for 'remap'\n");
		quit(-1);
	}
	new=numeric();
	for(i in 1:len){
		ix=which(x[i]==key);
		if(length(ix)==0){
			if(leave_unmapped_alone){
				new[i]=x[i];
			}else{
				new[i]=NA;
			}
		}else{
			new[i]=value[ix];
		}
	}
	
	# Determine whether to convert results to numeric
	non_na_ix=!is.na(new);
	numeric_try=as.numeric(new[non_na_ix]);
	if(any(is.na(numeric_try))){
		# leave alone, it still looks like it's non-numeric
	}else{
		# convert to numeric
		new=as.numeric(new);
	}

	return(new);
}

redefine_NA=function(x, value){
	na_ix=is.na(x);
	x[na_ix]=value;
	return(x);	
}

function.list=function(fun, arglist, na.rm=T){
	m=matrix(unlist(arglist), byrow=F, ncol=length(arglist));
	out=apply(m, 1, function(x){fun(x, na.rm=na.rm)});	
	return(out);
}

offsets_by_group=function(abs, ref, grp){
# This function will calculate the offsets (min(c(abs,ref)) is 0) for abs.  
	uniq_grps=unique(grp);
	num_uniq_grp=length(uniq_grps);
	num_rows=length(abs);
	out=rep(0, num_rows);
	for(i in 1:num_uniq_grp){
		grp_ix=(grp==uniq_grps[i]);
		grp_val=abs[grp_ix];
		if(is.null(ref)){
			min_val=min(grp_val, na.rm=T);
		}else{
			min_val=min(c(grp_val, ref[grp_ix]), na.rm=T);
		}
		out[grp_ix]=grp_val-min_val;
	}
	return(out);
}

indices_by_group=function(abs, grp){
	uniq_grps=unique(grp);
	num_uniq_grp=length(uniq_grps);
	num_rows=length(abs);
	out=rep(0, num_rows);
	for(i in 1:num_uniq_grp){
		grp_ix=which(grp==uniq_grps[i]);
		grp_val=abs[grp_ix];
		out[grp_ix]=rank(grp_val);
	}
	return(out);
}

to.bool=function(x){
	uppered=toupper(x);

	bools=rep(NA, length(x));

	ones=grep("YES", uppered);
	ones=c(ones, grep("TRUE", uppered));
	ones=c(ones, grep("ON", uppered));
	ones=c(ones, grep("T", uppered));

	zeros=grep("NO", uppered);
	zeros=c(zeros, grep("FALSE", uppered));
	zeros=c(zeros, grep("OFF", uppered));
	zeros=c(zeros, grep("F", uppered));

	bools[zeros]=0;
	bools[ones]=1;

	return(bools);

}

mask=function(x, bool_arr, mask_val){
	if(is.numeric(bool_arr)){
		bool_arr=bool_arr>0;
	}
	if(!is.numeric(x)){
		x=as.character(x);
		x[bool_arr]=mask_val;
	}else{
		x[bool_arr]=mask_val;
	}
	
	return(x);
}

mean_center=function(x){
	meanx=mean(x);
	cat("Mean was: ", meanx, "\n");
	return(x-meanx);
}

#------------------------------------------------------------------------------

str.left=function(x, n){
	x=as.character(x);
	substr(x, 1, n);	
}

str.right=function(x, n){
	x=as.character(x);
	last=nchar(x);
	substr(x, last-n+1, last);	
}

str.chop_left=function(x, n){
	x=as.character(x);
	last=nchar(x);
	substr(x, n+1, last);	
}

str.chop_right=function(x, n){
	x=as.character(x);
	last=nchar(x);
	substr(x, 1, last-n);	
}


str.split_keep=function(x, sep="\\.", keep_idx, join="."){
	arr_len=length(x);
	out_arr=character(arr_len);
	for(i in 1:arr_len){
		splits=strsplit(x[i], sep)[[1]];
		out_arr[i]=paste(splits[keep_idx], collapse=join);
	}
	return(out_arr);
}


##Added by ACF


#This function adjusts splitting for 0159 MEDBIO sequencingIDs which 
#contain an extra field after the studyID. 
str.split_keep_MDBIO=function(x, sep="\\.", keep_idx, join="."){
        arr_len=length(x);
        out_arr=character(arr_len);
	keep_idx_MB=keep_idx+1
	for(i in 1:arr_len){
                splits=strsplit(x[i], sep)[[1]];
		if (identical(splits[1],"0159")){
			out_arr[i]=paste(splits[keep_idx_MB], collapse=join);
		}else{
			out_arr[i]=paste(splits[keep_idx], collapse=join);
		}
	}
	return(out_arr);
}

#Used to reformat date conventions parsed from sequencingIDs. Standard format 
#in the sequencingIDs is YYYYDDMM, this script will parse a column of dates in that format and 
#return as DD/MM/YYYY. 
date.reformat_CMM=function(x, split=character(0), join="/"){
	arr_len=length(x);
	out_arr=character(arr_len);
	for(i in 1:arr_len){
		splits=strsplit(as.character(x[i]), split)[[1]];
		if (length(splits)==8){
			Y=paste(splits[1],splits[2],splits[3],splits[4],sep="")
			D=paste(splits[5],splits[6],sep="")
			M=paste(splits[7],splits[8],sep="")
			out_arr[i]=paste(D,M,Y,sep=join)
		}else{
			out_arr[i]=x[i]
		}
	}
	return(out_arr);
}



#Used to mark the min and max offsets for a given group (ie the first and last sample)
#creates a boolean vector

return_min_max_of_offset <- function(grp, abs, ref = NULL) {
  uniq_grps <- unique(grp)  # Get unique group names
  num_uniq_grp <- length(uniq_grps)  # Number of unique groups
  num_rows <- length(abs)  # Number of rows in 'abs'
  out <- rep(0, num_rows)  # Initialize the output vector
  
  # Loop through each unique group
  for (i in 1:num_uniq_grp) {
    grp_ix <- (grp == uniq_grps[i])  # Boolean vector for group membership
    grp_val <- abs[grp_ix]  # Values corresponding to the current group
    
    # Compute min/max for the group (and reference if provided)
    if (is.null(ref)) {
      min_val <- min(grp_val, na.rm = TRUE)
      max_val <- max(grp_val, na.rm = TRUE)
    } else {
      # Combine the group values with the reference if provided
      ref_val <- ref[grp_ix]
      min_val <- min(c(grp_val, ref_val), na.rm = TRUE)
      max_val <- max(c(grp_val, ref_val), na.rm = TRUE)
    }
    
    # Assign 1 for min or max values, otherwise 0
    out[grp_ix] <- ifelse(grp_val == min_val | grp_val == max_val, 1, 0)
  }
  
  return(out)
}


periodicity_by_group <- function(abs, grp) {
  # This function calculates the periodicity for abs,
  # Handles unsorted data by sorting within each group.
  
  uniq_grps <- unique(grp)  # Get unique groups
  num_uniq_grp <- length(uniq_grps)  # Number of unique groups
  num_rows <- length(abs)  # Number of rows in the 'abs' vector
  out <- rep(0, num_rows)  # Create a vector of 0s the length of input vector
  
  for (i in 1:num_uniq_grp) {
    grp_ix <- (grp == uniq_grps[i])  # Boolean vector for group membership
    int_vect <- which(grp_ix)  # Indices of the group members
    grp_val <- abs[grp_ix]  # Corresponding values for the group
    
    # Skip groups with only one sample
    if (length(grp_val) < 2) {
      next
    }
    
    # Sort the group values (and preserve the original indices)
    sorted_indices <- order(grp_val)  # Get sorted indices
    sorted_grp_val <- grp_val[sorted_indices]  # Get sorted values
    
    # Loop over pairs of samples (now sorted within the group)
    for (j in 1:(length(sorted_grp_val) - 1)) {  # We need to stop before the last pair
      # Find the original indices of the sorted values
      orig_index_1 <- int_vect[sorted_indices[j]]
      orig_index_2 <- int_vect[sorted_indices[j + 1]]
      
      # Calculate the periodicity difference (difference between consecutive sorted values)
      diff_val <- sorted_grp_val[j + 1] - sorted_grp_val[j]
      out[orig_index_1] <- diff_val
      out[orig_index_2] <- diff_val
    }
    
    # Set the last entry of each group to NA (no periodicity value for the last entry)
    last_index <- int_vect[sorted_indices[length(sorted_grp_val)]]
    out[last_index] <- NA
  }
  
  return(out)
}


date_diff_pair=function(abs, grp){
  #this function will calculate the difference in date between two samples in a group
  #and output that value for both samples. 
  #Metadata should be trimmed down to the pairs of samples prior to using (ie
  #use the paired map to trim down the dataset first). 
  #Useful if you want to use the difference between two samples as a cov_var in a paired block
  uniq_grps=unique(grp);
  num_uniq_grp=length(uniq_grps);
  num_rows=length(abs);
  out=rep(0, num_rows); #creates vector of 0s the length of input column
  for(i in 1:num_uniq_grp){
    grp_ix=(grp==uniq_grps[i]); #creates a boolean vector indicating group status
    int_vect=which(grp_ix); #returns index number of group status from boolean
    grp_val=abs[grp_ix];
    for(j in 1:(length(int_vect)-1)){
      out[int_vect[j]]=grp_val[j+1]-grp_val[j];
      out[int_vect[j+1]]=grp_val[j+1]-grp_val[j];
    }

  }

  return(out);

}



### will retrieve CMM formatted date (YYYYMMDD) from a column of sampleIDs
date_retriever=function(col, sep="[.]", len=8){
  num_rows=length(col);
  out=rep(0, num_rows);
  for (i in 1:num_rows){
    splits=strsplit(col[i], sep);
    for (j in 1:length(splits[[1]])){
      part=(as.numeric(splits[[1]][j]))
      if (!is.na(part) & nchar(part)==len & part>19000000 & part<21500000){
        out[i]=part
      }
    }
  }
  return(out);
}



#------------------------------------------------------------------------------

index=function(start=1){
	# This will generate an index for each row in the input file
	return(seq(start, num_samples));
}

#------------------------------------------------------------------------------

days_from_date=function(x, format){
	# This will convert a date string to the number of days since Jan 1, 1970.
	if(is.null(format)){
		cat("Error:  days_from_date requires a date string format definition.\n");
		quit(-1);
	}
	return(as.numeric(as.Date(x, format)));
}

num_to_str_id=function(numeric_id, prefix="s"){
print(names(numeric_id));
	max_val=max(numeric_id);
	num_digits=log10(max_val+1)+1;
	print(numeric_id);
	template_str=paste(prefix, "%0", num_digits, "g", sep="");
	num_char=sprintf(template_str, numeric_id);
	return(num_char);

}

#------------------------------------------------------------------------------

set_LOQ=function(x, detection_limit_value, method){

	dl_pos=(x==detection_limit_value);
	values=x[!dl_pos];
	min_avail=min(values);
	num_abv_dl=length(values);
	cat("Num values above DL: ", num_abv_dl, "\n");

	if(method=="zero"){
		x[dl_pos]=0;
	}else if(method=="min_div10"){
		x[dl_pos]=min_avail/10;
	}else if(method=="min_div02"){
		x[dl_pos]=min_avail/2;
	}else if(method=="expected"){

		# Test for normality
		shap.res=shapiro.test(values);
		
		# Add 1 if any 0's
		if(any(values==0)){
			log_val=log(values+1);
			p1=T;
		}else{
			log_val=log(values);
			p1=F;
		}

		# Test transform for normality
		shap.res.log=shapiro.test(log_val);

		# If transform pvalue is greater than untransformed, then keep transform
		if(shap.res$p.value<shap.res.log$p.value){
			cat("Transforming for normality.\n");
			keep_trans=T;	
			calc_val=log_val;
		}else{
			keep_trans=F;
			calc_val=values;
		}

		min_calc_val=min(calc_val);

		# If there are many DL values not represented, 
		# mean will be over estimated, so use mode
		dens=density(calc_val);
		mode=dens$x[which.max(dens$y)];
		cat("Estimated Mode: ", mode, "\n");

		# Estimate sd based values above mode
		ab_mod_ix=(calc_val>=mode);
		num_abv=sum(ab_mod_ix);
		sum_sqr=sum((calc_val[ab_mod_ix]-mode)^2);
		sd=sqrt(sum_sqr/num_abv);
		cat("Estimated SD: ", sd, " (n=", num_abv, ")\n");
			
		pr_x_lt_dl=pnorm(min_calc_val, mode, sd);
		exp_val_below_dl=qnorm(pr_x_lt_dl/2, mode, sd);

		cat("Detection Limit: ", min_calc_val, "\n");
		cat("Prob(X<DL): ", pr_x_lt_dl, "\n");
		cat("E[X<DL]: ", exp_val_below_dl, "\n");

		# Undo transform
		if(keep_trans){
			loqv=exp(exp_val_below_dl);
			if(p1){
				loqv=loqv-1;
			}	
			cat("Estimated Untransformed LOQ: ", loqv, "\n");
		}else{
			loqv=exp_val_below_dl;
		}

		x[dl_pos]=loqv;

		cat("After LOQ Analysis:\n");
		print(x);
		cat("\n");
	}
	return(x);

}

##############################################################################

# Load factors
factors=load_factors(InputFName);
num_samples=nrow(factors);

# Load commands
commands=load_commands(Formulas);
num_commands=length(commands);

cat("Number of Commands: ", num_commands, "\n");

print(commands);
for(cmd in commands){
	cat("\n");

	cmd=strsplit(cmd, "#")[[1]][1]; # Strip off comments
	if(is.na(cmd) || length(cmd)==0 || cmd == ""){
		next;
	}

	cmd=gsub("^\\s+", "", cmd);
	cmd=gsub("\\s+$", "", cmd);

	print(cmd);

	cat("Working on: ", cmd, "\n");

	if(length(grep("^delete ", cmd))==1){
		# Delete variable from factors
		var=strsplit(cmd, "\\s+")[[1]][2];
		cat("Deleting: ", var, "\n"); 
		cnames=colnames(factors);
		cnames=setdiff(cnames, var);
		factors=factors[,cnames, drop=F];
	}else if(length(grep("^keep ", cmd))==1){
		# Remove rows with factors that are F
		var=strsplit(cmd, "\\s+")[[1]][2];
                cat("Keeping Rows where ", var, " is TRUE\n", sep="");
		keep_ix=factors[,var];
		factors=factors[keep_ix,, drop=F];
		rowcol=dim(factors);
		cat("Rows: ", rowcol[1], " x Cols: ", rowcol[2], "\n", sep="");
	}else if(length(grep("^make_key ", cmd))==1){
		# move column to first position
		var=strsplit(cmd, "\\s+")[[1]][2];
		cat("Making ", var, " key column.\n", sep="");
		key_col_val=factors[, var, drop=F];
		cnames=colnames(factors);
		cnames=setdiff(cnames, var);
		factors=cbind(key_col_val, factors[,cnames,drop=F]);
	}else if(length(grep("^print ", cmd))==1){
		var=strsplit(cmd, "\\s+")[[1]][2];
		cat("Printing ", var, "\n", sep="");
		print(factors[, var, drop=F]);
	}else if(length(grep("^quit", cmd))==1){
		cat("Forcing quit...\n");
		quit("yes");
	}else{
		# Add variable to factors
		#cmd=gsub("\\s+", "", cmd);
		lhs=strsplit(cmd, "=")[[1]][1];
		cat("LHS: ", lhs, "\n");
		results=eval(parse(text=cmd), envir=factors);
		print(results);
		cnames=colnames(factors);

		if(any(lhs==cnames)){
			# Replace
			factors[,lhs]=results;
		}else{
			# Append
			factors=cbind(factors, results, stringsAsFactors=F);
			colnames(factors)=c(cnames, lhs);
		}
	}
	
	cat("ok.\n");
}

cat("\n");

# Report any columns with no information
num_factors=ncol(factors);
factor_names=colnames(factors);
for(i in 1:num_factors){
	na_ix=is.na(factors[,i]);
	uniqs=unique(factors[!na_ix,i]);
	
	if(length(uniqs)<=1){
		cat("Warning: \"", factor_names[i], "\" has no information. (All \"", uniqs, "\")\n", sep="");
	}	
}
cat("\n");

write_factors(OutputFName, factors);

##############################################################################

cat("\nDone.\n");

print(warnings());
q(status=0);
