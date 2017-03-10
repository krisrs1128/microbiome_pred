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
library("ape")

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
  samples <- sample_data(ps)
  subjects <- model.matrix(
    ~ subject_ - 1,
    data = data.frame("subject_" = samples$Subject)
  ) %>%
    as_data_frame()
  subjects$Meas_ID = samples$Meas_ID

  melted_counts %>%
    left_join(subjects)
}

phylo_coords <- function(melted_counts, ps, k = 2) {
  tree <- phy_tree(ps)
  D <- cophenetic.phylo(tree)
  coord <- cmdscale(D, k) %>%
    data.frame()
  colnames(coord) <- gsub("X", "phylo_coord_", colnames(coord))
  coord$rsv <- rownames(coord)

  melted_counts %>%
    left_join(coord) %>%
    left_join(sample_data(ps)) %>%
    select(Meas_ID, rsv, starts_with("phylo_coord_")) %>%
    as_data_frame()
}
