#! /usr/bin/env Rscript

## File description -------------------------------------------------------------
## R script for outputing feature sets generated for different train / test data.

## ---- arguments ----
args <- commandArgs(trailingOnly = TRUE)

message("Executing features.R with arguments:")
message(paste(args, collapse = "\n"))

features_conf <- args[[1]]
melted_counts_path <- args[[2]]
cv_data_path <- args[[3]]
ps_path <- args[[4]]
output_path <- args[[5]]

## ---- libraries ----
library("plyr")
library("dplyr")
library("jsonlite")
library("feather")
source("src/utils/feature_funs.R")

## ---- read-input ----
melted_counts <- read_feather(melted_counts_path)
cv_data <- read_feather(cv_data_path)
phyloseq_object <- readRDS(ps_path)
opts <- read_json(features_conf)

## ---- create-features ----
## Features split across cv folds
for (k in c("all-cv", seq_len(max(cv_data$fold, na.rm = TRUE)))) {
  for (test_flag in c(TRUE, FALSE)) {

    x <- NULL
    for (i in seq_along(opts)) {
      f <- get(names(opts)[[i]])
      cv_f <- feature_fun_generator(f, melted_counts, cv_data, phyloseq_object)

      test_indic <- ifelse(test_flag, "test", "train")
      new_x <- do.call(cv_f, c(list(test_flag, k), opts[[i]]))

      if (is.null(x)) {
        x <- new_x
      } else {
        x <- x %>%
          full_join(new_x)
      }
    }

    write_feather(x, sprintf("%s-%s-%s.feather", output_path, test_indic, k))
  }
}

## Features on full data
x <- NULL
for (i in seq_along(opts)) {
  f <- get(names(opts)[[i]])
  new_x <- do.call(f, c(list(melted_counts, phyloseq_object), opts[[i]]))

  if (is.null(x)) {
    x <- new_x
  } else {
    x <- x %>%
      full_join(new_x)
  }
}
write_feather(x, sprintf("%s-all.feather", output_path))
