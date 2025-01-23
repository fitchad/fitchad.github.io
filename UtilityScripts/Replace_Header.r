#!/usr/bin/env Rscript

###############################################################################
#This script will read in a tsv file with an awful header, NULL the header, and replace with the newHeader.
#You will have to type out the vector in the list below, or read in a file with the header names.
#The input text file with the new header names should be a 1 dimentional list with no header value [1 column, N of rows to match the total number of columns in original file]
#Pre check for the correct dimensions of the old/new header prior



library('getopt')

params = c(
    "input_file", "i", 1, "character",   # Input file (IDF)
    "header_file", "h", 2, "character",  # Header file (IHF)
    "output_file", "o", 2, "character",  # Output file (ODF)
    "remove_lines", "r", 2, "character"  # Lines to remove from the input file
)

opt = getopt(spec = matrix(params, ncol = 4, byrow = TRUE), debug = FALSE)

# Check if input parameters are provided
if (!length(opt$input_file) || !length(opt$header_file)) {
    cat("Usage:\n")
    cat("  -i <input_file>   Input data file\n")
    cat("  -h <header_file>  Header file (used for column names)\n")
    cat("  -o <output_file>  Output file (default: 'output.tsv')\n")
    cat("  [-r <remove_lines>] Optional: Comma-separated list of line numbers to remove (e.g. '2,4,6' or '2:5')\n")
    q(status = -1)
}

InputFileName = opt$input_file
HeaderFileName = opt$header_file

# Output file (use default if not provided)
if (length(opt$output_file)) {
    OutputFileName = opt$output_file
} else {
    OutputFileName = "output.tsv"
    cat("No output file specified. Using 'output.tsv' as default.\n")
}

# Read the data file
df = read.csv(InputFileName, header = TRUE, comment.char = "", sep = "\t")

# Print the dimensions of the data file
cat("Dimensions of the data file:\n")
cat(dim(df), "\n")

# If the user specified lines to remove, process that
if (length(opt$remove_lines)) {
    lines_to_remove = opt$remove_lines
    # Parse the remove_lines argument
    lines_to_remove = unlist(strsplit(lines_to_remove, ","))
    # Convert the lines to remove into a numeric vector
    remove_indices = c()
    for (line in lines_to_remove) {
        if (grepl(":", line)) {
            # Handle ranges like 2:5
            range_parts = as.integer(unlist(strsplit(line, ":")))
            remove_indices = c(remove_indices, seq(range_parts[1], range_parts[2]))
        } else {
            remove_indices = c(remove_indices, as.integer(line))
        }
    }
    # Remove the specified lines (adjust for 1-based index)
    df = df[-remove_indices, ]
    cat("Removed the following lines:\n")
    print(remove_indices)
} else {
    cat("No lines specified for removal.\n")
}

# Read the header file
newHeader = read.csv(HeaderFileName, header = FALSE)

# Print the dimensions of the header file
cat("Dimensions of the header file:\n")
cat(dim(newHeader), "\n")

# Set the column names of the data frame
colnames(df) <- newHeader[, 1]

# Print the first few rows to check
cat("First few rows of the data frame:\n")
print(head(df))

# Write the updated data to the output file
write.table(df, OutputFileName, sep = "\t", quote = FALSE, row.names = FALSE)

cat("Output written to:", OutputFileName, "\n")
