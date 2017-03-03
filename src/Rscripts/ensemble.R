#! /usr/bin/env Rscript

## File description -------------------------------------------------------------
## R script for ensembling results across trained models and saving predictions
## to file.

## ---- arguments ----
args <- commandArgs(trailingOnly = TRUE)

message("Executing ensemble.R with arguments:")
message(paste(args, collapse = "\n"))

preds_basename <- args[[1]]
models_basenames <- strsplit(args[[1]], ";")[[1]]
y_basename <- args[[2]]
k_folds <- as.integer(args[[3]])
new_data_path <- args[[4]]
output_path <- args[[5]]
ensemble_conf <- args[[6]]

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
  for (m in seq_along(models_basenames)) {
    models_list[[k]][[m]] <- get(load(sprintf("%s-%s.RData", models_basenames[m], k)))
  }
}

new_data <- read_feather(new_data_path)

## ---- ensemble ----
f <- get(ensemble_opts$method)
x <- list("a", "b", "c")
rep(x, 3)
z <- list(list("1", "2", "3"), list("4", "5", "6"), list("7", "8", "9"))

preds_list <- rep(preds_list, each = length(models_basenames))
y_list <- rep(y_list, each = length(models_basenames))
models_list <- do.call(c, models_list)
trained_ensemble <- f(models_list, preds_list, models_list)

y_hat <- trained_ensemble$ens_predict(new_data)
write_feather(y_hat, output_path)
