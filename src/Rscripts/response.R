#! /usr/bin/env Rscript

## File description -------------------------------------------------------------
## R script for outputing feature sets generated for different train / test data.

## ---- arguments ----
args <- commandArgs(trailingOnly = TRUE)

message("Executing response.R with arguments:")
message(paste(args, collapse = "\n"))

melted_counts_path <- args[[1]]
cv_data_path <- args[[2]]
ps_path <- args[[3]]
output_path <- args[[4]]

## ---- libraries ----
library("plyr")
library("dplyr")
library("feather")
source("src/utils/feature_funs.R")

## ---- read-input ----
melted_counts <- read_feather(melted_counts_path)
cv_data <- read_feather(cv_data_path)
phyloseq_object <- readRDS(ps_path)

## ---- create-responses ----
response_fun <- function(melted_counts, phyloseq_object) {
  melted_counts
}

for (k in c("all-cv", seq_len(max(cv_data$fold, na.rm = TRUE)))) {
  for (test_flag in c(TRUE, FALSE)) {
    cv_response <- feature_fun_generator(
      response_fun,
      melted_counts,
      cv_data,
      phyloseq_object
    )

    test_indic <- ifelse(test_flag, "test", "train")
    y <- cv_response(test_flag, k)
    write_feather(y, sprintf("%s-%s-%s.feather", output_path, test_indic, k))
  }
}

write_feather(melted_counts, sprintf("%s-all.feather", output_path))
