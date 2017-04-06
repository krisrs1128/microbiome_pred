#! /usr/bin/env Rscript

## File description -------------------------------------------------------------
## Functions for getting different kinds of responses from melted counts

response_fun <- function(melted_counts, phyloseq_object) {
  melted_counts
}

binary_response <- function(melted_counts, phyloseq_object) {
  melted_counts$counts <- ifelse(melted_counts$counts > 0, 1, 0)
  melted_counts
}
