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
library("tools")
library("doParallel")
source("src/utils/models.R")

## ---- train-model ----
x <- read_feather(x_path)
y <- read_feather(y_path)

## ---- convert-model-opts ----
model_opts <- read_json(model_conf, simplifyVector = TRUE, simplifyDataFrame = TRUE)
if (file_ext(model_opts$method) == "RData") {
  model_opts$method <- get(load(model_opts$method))
}
model_opts$trControl <- do.call(trainControl, model_opts$train_control_opts)
model_opts$train_control_opts <- NULL

## ---- train-model ----
stopifnot(all(x$Meas_ID == y$Meas_ID))
stopifnot(all(x$rsv == y$rsv))

x <- x %>%
  select(-Meas_ID, -rsv) %>%
  as.matrix()

y <- y %>%
  select(count) %>%
  unlist() %>%
  as.numeric()

cl <- makeCluster(min(4, detectCores()))
registerDoParallel(cl)
model_res <- do.call(train, c(list("x" = x, "y" = y), model_opts))

## ---- save-result ----
dir.create(dirname(output_path), recursive = TRUE)
save(model_res, file = output_path)
