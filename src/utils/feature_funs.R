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
  function(test_flag, leave_out_fold = "all") {
    if (leave_out_fold == "all") {
      ## case that we are looking at global train / test
      subset_counts <- cv_data %>%
        filter(validation == test_flag)
    } else if (test_flag) {
      ## case that we are looking at cv test set within global train
      subset_counts <- cv_data %>%
        filter(
          !validation,
          k == leave_out_fold
        )
    } else {
      ## case that we are looking at cv train set within global train
      subset_counts <- cv_data %>%
        filter(
          !validation,
          k != leave_out_fold
        )
    }

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
