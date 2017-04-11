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

person_subsample <- function(ps, ids = NULL) {
  if (is.null(ids)) {
    ids <- unique(sample_data(ps)$Subject)
  }
  new_ps <- prune_samples(
    sample_data(ps)$Subject %in% ids,
    ps
  )
  sample_data(new_ps)$Subject <- droplevels(sample_data(new_ps)$Subject)
  new_ps
}

filter_qcs <- function(ps) {
  prune_samples(
    sample_data(ps)$Subject != "DNA_QC",
    ps
  )
}

filter_low_reads <- function(ps) {
  low_reads_meas <- c(
    "M124",
    "M416",
    "M395",
    "M472",
    "M477",
    "M478",
    "M479",
    "M480",
    "M481",
    "M482",
    "M483",
    "M485",
    "M486",
    "M487",
    "M488",
    "M491",
    "M492",
    "M495",
    "M496"
  )
  prune_samples(
    !(sample_data(ps)$Meas_ID %in% low_reads_meas),
    ps
  )
}
