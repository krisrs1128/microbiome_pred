#! /usr/bin/env Rscript

## File description -------------------------------------------------------------
## Functions to generate features from the raw training data

## ---- libraries ----
library("plyr")
library("dplyr")
library("feather")
library("phyloseq")
library("zoo")
library("caret")

## ---- functions ----
feature_fun_generator <- function(f, melted_counts, cv_data, ps) {
  function(test_flag, leave_out_fold = "all-cv", ...) {
    subset_counts <- melted_counts %>%
      left_join(cv_data)

    if (leave_out_fold == "all-cv") {
      ## case that we are looking at global train / test
      subset_counts <- subset_counts %>%
        filter(validation == test_flag)
    } else if (test_flag) {
      ## case that we are looking at cv test set within global train
      subset_counts <- subset_counts %>%
        filter(
          validation != TRUE,
          fold == leave_out_fold
        )
    } else {
      ## case that we are looking at cv train set within global train
      subset_counts <- subset_counts %>%
        filter(
          validation != TRUE,
          fold != leave_out_fold
        )
    }

    f(subset_counts, ps, ...)
  }
}

#' @examples
#' cv_cc_relday <- feature_fun_generator(cc_relday, melted_counts, cv_data, ps)
#' holdout <- cv_cc_relday(FALSE, 1)
cc_relday <- function(melted_counts, ps) {
  samples <- sample_data(ps)
  samples$CC_RelDay <- na.locf(samples$CC_RelDay)
  melted_counts %>%
    left_join(samples) %>%
    select(Meas_ID, rsv, CC_RelDay) %>%
    rename(relative_day = CC_RelDay)
}

person_id <- function(melted_counts, ps) {
  model.matrix(
    ~ subject - 1,
    data = data.frame(subject = sample_data(ps)$Subject)
  ) %>%
    as.matrix()
}
