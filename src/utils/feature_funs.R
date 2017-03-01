#! /usr/bin/env Rscript

## File description -------------------------------------------------------------
## Functions to generate features from the raw training data

## ---- libraries ----
library("plyr")
library("dplyr")
library("feather")
library("phyloseq")

## ---- functions ----
feature_fun_generator <- function(f, melted_counts, cv_data, phyloseq_object) {
  function(validation_flag, leave_out_fold) {
    ## filter to current indices
    subset_counts <- cv_data %>%
      filter(
        validation == validation_flag,
        fold != leave_out_fold
      )

    f(subset_counts, phyloseq_object)
  }
}

#' @examples
#' cv_cc_relday <- feature_fun_generator(cc_relday, melted_counts, cv_data, phyloseq_object)
#' holdout <- cv_cc_relday(FALSE, 1)
cc_relday <- function(melted_counts, phyloseq_object) {
  samples <- sample_data(phyloseq_object)
  melted_counts %>%
    left_join(samples) %>%
    select(Meas_ID, rsv, CC_RelDay) %>%
    rename(relative_day = CC_RelDay)
}

