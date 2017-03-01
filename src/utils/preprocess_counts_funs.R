#! /usr/bin/env Rscript

## File description -------------------------------------------------------------
## Functions available for preprocessing a phyloseq object. Always input and
## output phyloseq objects, in order to use with preprocess_counts.R script.

## ---- libraries ----
library("plyr")
library("dplyr")
library("phyloseq")

## ---- functions ----
asinh_transform <- function(ps) {
  ps %>%
    transform_sample_counts(asinh)
}

variance_filter <- function(ps, top_k = 100) {
  vars <- apply(get_taxa(ps), 2, var)
  threshold <- sort(vars, decreasing = TRUE)[min(ntaxa(ps), top_k)]
  ps %>%
    filter_taxa(function(x) var(x) >= threshold, TRUE)
}
