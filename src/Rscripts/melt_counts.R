#! /usr/bin/env Rscript

## File description -------------------------------------------------------------
## R script for melting and saving the counts matrix from a phyloseq object

## ---- arguments ----
args <- commandArgs(trailingOnly = TRUE)

message("Executing melt_counts.R with arguments:")
message(paste(args, collapse = "\n"))
ps_path <- args[[1]]
output_path <- args[[2]]

## ---- libraries ----
library("feather")
library("reshape2")
library("dplyr")
library("phyloseq")

## ---- reshape ----
ps <- readRDS(ps_path)
m_x <- get_taxa(ps) %>%
  melt(
    varnames = c("sample", "rsv"),
    value.name = "count"
  )

write_feather(m_x, path = output_path)
