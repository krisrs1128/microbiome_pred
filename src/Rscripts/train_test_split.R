#! /usr/bin/env Rscript

## File description -------------------------------------------------------------
## R script for creating version of melted counts with train test splits

## ---- arguments ----
args <- commandArgs(trailingOnly = TRUE)

message("Executing train_test_split.R with arguments:")
message(paste(args, collapse = "\n"))

melted_counts_path <- args[[1]]
output_path <- args[[2]]
validation_prop <- as.numeric(args[[3]])
k_folds <- as.integer(args[[4]])

## ---- libraries ----
library("feather")
library("plyr")
library("dplyr")

## ---- create-validation ----
mx <- read_feather(melted_counts_path) %>%
  select(-count)
N <- nrow(mx)
mx$validation <- sample(
  c(TRUE, FALSE),
  N,
  prob = c(validation_prop, 1 - validation_prop),
  replace = TRUE
)

## ---- create-folds ----
N_train <- mx %>%
  filter(!validation) %>%
  nrow()
folds <- sample(
  seq_len(k_folds),
  N_train,
  replace = TRUE
)
mx$fold <- NA
mx[!mx$validation, ]$fold <- folds

## ---- write-output ----
write_feather(mx, output_path)
