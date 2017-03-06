#! /usr/bin/env Rscript

## File description -------------------------------------------------------------
## R script for ensembling results across trained models and saving fitted
## models to file.

## ---- arguments ----
args <- commandArgs(trailingOnly = TRUE)

message("Executing ensemble.R with arguments:")
message(paste(args, collapse = "\n"))

preds_basenames <- strsplit(args[[1]], ";")[[1]]
models_basenames <- strsplit(args[[2]], ";")[[1]]
y_basename <- args[[3]]
k_folds <- as.integer(args[[4]])
output_path <- args[[5]]
ensemble_conf <- args[[6]]
ensemble_id <- args[[7]]

## ---- libraries ----
library("caret")
library("dplyr")
library("feather")
library("jsonlite")
source("src/utils/ensemble_funs.R")

## ---- read-data ---
ensemble_opts <- read_json(ensemble_conf)[[ensemble_id]]

models_list <- list()
preds_list <- list()
y_list <- list()

for (k in c(seq_len(k_folds), "all-cv")) {
  y_list[[k]] <- read_feather(sprintf("%s-test-%s.feather", y_basename, k))

  preds_list[[k]] <- list()
  for (i in seq_along(preds_basenames)) {
    preds_list[[k]][[i]] <- read_feather(sprintf("%s-%s.feather", preds_basenames[i], k))
  }

  models_list[[k]] <- list()
  for (i in seq_along(models_basenames)) {
    models_list[[k]][[i]] <- get(load(sprintf("%s-%s.RData", models_basenames[i], k)))
  }
}

## ---- ensemble-cv ----
f <- get(ensemble_opts$method)

y_list <- rep(y_list, each = length(models_basenames))
models_list <- unlist(models_list, recursive = FALSE)
preds_list <- unlist(preds_list, recursive = FALSE)
trained_ensemble <- f(models_list, preds_list, y_list)
save(trained_ensemble, file = sprintf("%s-cv_trained.RData", output_path))

## ---- ensemble-all ----
## no longer restrict ourselves to non-validation data
y_list <- list()
models_list <- list()
preds_list <- list()

for (i in seq_along(preds_basenames)) {
  preds_list[[i]] <- read_feather(sprintf("%s-all.feather", preds_basenames[i]))
}
for (i in seq_along(models_basenames)) {
  models_list[[i]] <- get(load(sprintf("%s-all.RData", models_basenames[i])))
}

trained_ensemble <- f(models_list, preds_list, y_list)
save(trained_ensemble, file = sprintf("%s-full_trained.RData", output_path))
