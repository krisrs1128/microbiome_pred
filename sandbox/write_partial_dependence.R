#! /usr/bin/env Rscript

## File description -------------------------------------------------------------
## Script to get the partial dependence wrt time, subject, and phylogenetic index

args <- commandArgs(trailingOnly = TRUE)
model_path <- args[[1]]
dependence_type <- args[[2]]

library("feather")
library("dplyr")
library("tidyr")
library("SLURMHelpers")
source("src/utils/interpretation.R")

## create directory, read existing (full) data and models
dir.create("data/sandbox", recursive = TRUE)
X_path <- "data/processed/features/features_772570831040539-all.feather"
y_path <- "data/processed/responses/responses_616901990044369-all.feather"
X <- read_feather(X_path)
y <- read_feather(y_path)

###############################################################################
# Study time effects
###############################################################################

combined <- X %>%
  left_join(y) %>%
  gather_dummy("order", "Order") %>%
  gather_dummy("subject", "subject_") %>%
  mutate(
    order_top = recode_rare(order, 7),
    jittered_count = count + runif(n(), 0, 0.5),
    binarized_count = ifelse(count > 0, 0, 1)
  )

if (dependence_type == "time") {
  ## Get partial dependence, after averaging out phylogenetic features
  x_grid <- expand.grid(
    "relative_day" = seq(-100, 50, length.out = 100),
    "Order" = setdiff(unique(combined$order_top), "other"),
    "subject_" = c("AAA", "AAI")
  )

  input_data <- partial_dependence_input(X, x_grid)
  partial_dependence_write(
    get(load(model_path)),
    input_data,
    "data/sandbox/f_bar_rday_model_"
  )
} else {
  ## Get partial dependence, after averaging out phylogenetic features
  x_grid <- expand.grid(
    "phylo_ix" = seq(min(X$phylo_ix), max(X$phylo_ix), length.out = 100),
    "subject_" = c("AAA", "AAI")
  )

  input_data <- partial_dependence_input(X, x_grid)
  partial_dependence_write(
    get(load(model_path)),
    input_data,
    sprintf(
      "data/sandbox/f_bar_phylo_ix_%s",
      basename(tools::file_path_sans_ext(model_path))
    )
  )
}
