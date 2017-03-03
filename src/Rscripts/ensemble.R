#! /usr/bin/env Rscript

## File description -------------------------------------------------------------
## R script for ensembling results across trained models and saving predictions
## to file.

## ---- arguments ----
args <- commandArgs(trailingOnly = TRUE)

message("Executing ensemble.R with arguments:")
message(paste(args, collapse = "\n"))

preds_basename <- strsplit(args[[1]], ";")[[1]]
models_basenames <- strsplit(args[[2]], ";")[[1]]
y_basename <- args[[3]]
k_folds <- as.integer(args[[4]])
new_data_path <- args[[5]]
output_path <- args[[6]]
ensemble_conf <- args[[7]]

## ---- libraries ----
library("caret")
library("dplyr")
library("feather")
library("jsonlite")
source("src/utils/ensemble_funs.R")

## ---- read-data ---
ensemble_opts <- read_json(ensemble_conf)

models_list <- list()
preds_list <- list()
y_list <- list()

for (k in seq_len(k_folds)) {
  y_list[[k]] <- read_feather(sprintf("%s-test-%s.feather", y_basename, k))
  preds_list[[k]] <- read_feather(sprintf("%s-%s.feather", preds_basename, k))
  models_list[[k]] <- list()
  for (m in seq_along(models_basename)) {
    models_list[[k]][[m]] <- get(load(sprintf("%s-%s.RData", models_basename[m], k)))
  }
}

new_data <- read_feather(new_data_path) %>%
  select(-Meas_ID, -rsv) %>%
  as.matrix()

## ---- ensemble ----
f <- get(ensemble_opts$method)

preds_list <- rep(preds_list, each = length(models_basename))
y_list <- rep(y_list, each = length(models_basename))
models_list <- unlist(models_list, recursive = FALSE)
trained_ensemble <- f(models_list, preds_list, y_list)

y_hat <- trained_ensemble$ens_predict(new_data) %>%
  tbl_df() %>%
  rename(y_hat = value)
write_feather(y_hat, output_path)
