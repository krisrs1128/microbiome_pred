#! /usr/bin/env Rscript

## File description -------------------------------------------------------------
## R script for preprocessing a phyloseq object.

## ---- arguments ----
args <- commandArgs(trailingOnly = TRUE)

message("Executing preprocess_counts.R with arguments:")
message(paste(args, collapse = "\n"))
ps_path <- args[[1]]
preprocess_conf <- args[[2]]
output_path <- args[[3]]

## ---- libraries ----
library("phyloseq")
library("jsonlite")
source("../utils/preprocess_counts_funs.R")

## ---- read-input ----
ps <- readRDS(ps_path)
opts <- fromJSON(preprocess_conf)

## ---- apply-opts ----
for (i in seq_along(opts)) {
  f <- get(names(opts)[[i]])
  message(sprintf("Computing %s", names(opts)[[i]]))
  ps <- do.call(f, c(ps, opts[[i]]))
}

## ---- write-output ----
writeRDS(ps, output_path)
