#! /usr/bin/env Rscript

## File description -------------------------------------------------------------
## R script computing error metrics on the cross-validated data, and saving the
## results to file.

## ---- arguments ----
args <- commandArgs(trailingOnly = TRUE)

message("Executing cv_eval.R with arguments:")
message(paste(args, collapse = "\n"))

preds_path <- args[[1]]
y_path <- args[[2]]
eval_metrics <- strsplit(args[[3]], ";")[[1]]
output_path <- args[[4]]
preprocess_conf <- args[[5]]
features_conf <- args[[6]]
model_conf <- args[[7]]
validation_prop <- as.numeric(args[[8]])
k_folds <- as.integer(args[[9]])
cur_fold <- args[[10]]

## ---- libraries ----
library("caret")
library("dplyr")
library("feather")
library("jsonlite")
source("src/utils/eval_funs.R")

## ---- get-metrics ----
y <- read_feather(y_path) %>%
  select(count) %>%
  unlist() %>%
  as.numeric()
y_hat <- read_feather(preds_path) %>%
  select(y_hat) %>%
  unlist() %>%
  as.numeric()

err_list <- list()
for (i in seq_along(eval_metrics)) {
  L <- get(eval_metrics[[i]])

  err_list[[i]] <- list(
    "preprocess_conf" = preprocess_conf,
    "features_conf" = features_conf,
    "model_conf" = model_conf,
    "validation_prop" = validation_prop,
    "k_folds" = k_folds,
    "cur_fold" = cur_fold,
    "metric" = eval_metrics[i],
    "value" = L(y, y_hat)
  )
}

dir.create(dirname(output_path), recursive = TRUE)
write_feather(
  data.table::rbindlist(err_list),
  path = output_path
)
