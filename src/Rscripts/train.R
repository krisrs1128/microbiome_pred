#! /usr/bin/env Rscript

## File description -------------------------------------------------------------
## R script for training models on featurized data. We assume cv has been
## considered elsewhere.

## ---- arguments ----
args <- commandArgs(trailingOnly = TRUE)

message("Executing train.R with arguments:")
message(paste(args, collapse = "\n"))

x_path <- args[[1]]
y_path <- args[[2]]
output_path <- args[[3]]
model_conf <- args[[4]]

## ---- libraries ----
library("caret")
library("dplyr")
library("feather")
library("jsonlite")
library("doParallel")

## ---- train-model ----
x <- read_feather(x_path)
y <- read_feather(y_path)
model_opts <- read_json(model_conf)

stopifnot(x$Meas_ID == y$Meas_ID)
stopifnot(x$rsv == y$rsv)

x <- x %>%
  select(-Meas_ID, -rsv) %>%
  as.matrix()

y <- y %>%
  select(count) %>%
  unlist() %>%
  as.numeric()

n_cores <- detectCores()
cl <- makePSOCKcluster(n_cores)
registerDoParallel(cl)
model_res <- do.call(train, c(list("x" = x, "y" = y), model_opts))
stopCluster(cl)

## ---- save-result ----
save(model_res, file = output_path)
