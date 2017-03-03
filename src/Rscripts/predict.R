#! /usr/bin/env Rscript

## File description -------------------------------------------------------------
## R script for obtaining predictions from trained models.

## ---- arguments ----
args <- commandArgs(trailingOnly = TRUE)

message("Executing predict.R with arguments:")
message(paste(args, collapse = "\n"))

x_path <- args[[1]]
model_path <- args[[2]]
output_path <- args[[3]]

## ---- libraries ----
library("caret")
library("dplyr")
library("feather")

## ---- train-model ----
x <- read_feather(x_path)
model <- get(load(model_path))

x <- x %>%
  select(-Meas_ID, -rsv) %>%
  as.matrix()

y_hat <- predict(model, newdata = x) %>%
  tbl_df() %>%
  rename(y_hat = value)

## ---- save-result ----
write_feather(y_hat, path = output_path)
