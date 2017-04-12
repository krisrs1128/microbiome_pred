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
library("tidyr")

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
relative_day <- function(melted_counts, ps) {
  samples <- sample_data(ps)
  samples$CC_RelDay <- na.locf(samples$CC_RelDay)
  melted_counts %>%
    left_join(samples) %>%
    select(Meas_ID, rsv, CC_RelDay) %>%
    dplyr::rename(relative_day = CC_RelDay)
}

imm_post <- function(melted_counts, ps) {
  samples <- sample_data(ps)
  samples$CC_RelDay <- na.locf(samples$CC_RelDay)
  samples$imm_post <- ifelse(
    samples$CC_RelDay >= 0 & samples$CC_RelDay <= 3,
    1,
    0
  )

  melted_counts %>%
    left_join(samples) %>%
    select(Meas_ID, rsv, imm_post)
}

person_id <- function(melted_counts, ps) {
  samples <- sample_data(ps)
  samples$Subject <- droplevels(samples$Subject)
  subjects <- model.matrix(
    ~ subject_ - 1,
    data = data.frame("subject_" = samples$Subject)
  ) %>%
    as_data_frame()
  subjects$Meas_ID = samples$Meas_ID

  melted_counts %>%
    left_join(subjects) %>%
    select(Meas_ID, rsv, starts_with("subject"))
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
    select(Meas_ID, rsv, starts_with("phylo_coord_")) %>%
    as_data_frame()
}

phylo_ix <- function(melted_counts, ps) {
  tree <- ape::ladderize(phy_tree(ps))
  is_tip <- tree$edge[, 2] <= length(tree$tip.label)
  ordered_tips <- tree$edge[is_tip, 2]

  tip_map <- data_frame(
    "rsv" = factor(tree$tip.label[ordered_tips], levels = levels(melted_counts$rsv)),
    "phylo_ix" = seq_len(ntaxa(ps))
  )

  melted_counts %>%
    left_join(tip_map) %>%
    select(Meas_ID, rsv, phylo_ix)
}

taxa_features <- function(melted_counts, ps, levels = "Order") {
  taxa <- data.frame(tax_table(ps))
  taxa$rsv <- rownames(taxa)
  taxa <- sapply(taxa, as.character)

  ## impute by deepest known level
  for (i in seq_len(nrow(taxa))) {
    taxa[i, ] <- na.locf(taxa[i, ])
  }

  taxa <- taxa[, c(levels, "rsv")]
  features <- melted_counts %>%
    left_join(as_data_frame(taxa))
  fmla <- formula(sprintf("~ -1 + %s", paste0(levels, collapse = "+")))
  x <- model.matrix(fmla, features)
  cbind(features %>% select(Meas_ID, rsv), x) %>%
    as_data_frame()
}

pca_features <- function(melted_counts, ps, k = 3) {
  ## Reshape data so we can take pca
  x <- melted_counts %>%
    group_by(rsv, Meas_ID) %>%
    summarise(count = mean(count, na.rm = TRUE)) %>% ## average over folds
    ungroup() %>%
    spread(Meas_ID, count)
  x_mat <- x %>%
    select(-rsv) %>%
    as.matrix()
  x_mat[is.na(x_mat)] <- mean(x_mat, na.rm = TRUE)

  ## Create a PCA approximation
  pca_x <- svd(x_mat)
  evals <- pca_x$d
  x_coarse <- pca_x$u[, 1:k] %*% diag(evals[1:k]) %*% t(pca_x$v[, 1:k])
  colnames(x_coarse) <- colnames(x_mat)

  ## Melt back into features format
  pca_imputed <- cbind(
    "rsv" = x$rsv,
    as_data_frame(x_coarse)
  ) %>%
    gather("Meas_ID", "pca_imputed", -rsv)

  result <- melted_counts %>%
    left_join(pca_imputed)
  result$pca_imputed[is.na(result$pca_imputed)] <- mean(result$pca_imputed, na.rm = TRUE)
  result %>%
    select(Meas_ID, rsv, pca_imputed) %>%
    as_data_frame
}
