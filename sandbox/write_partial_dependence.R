#! /usr/bin/env Rscript

## File description -------------------------------------------------------------
## Script to get the partial dependence wrt time, subject, and phylogenetic index

library("feather")
library("dplyr")
library("tidyr")
source("src/utils/interpretation.R")

## create directory, read existing (full) data and models
dir.create("data/sandbox", recursive = TRUE)
X_path <- "data/processed/features/features_772570831040539-all.feather"
y_path <- "data/processed/responses/responses_616901990044369-all.feather"
model_paths <- list.files("data/processed/models/", "all.RData", full.names = TRUE)
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

## Get partial dependence, after averaging out phylogenetic features
x_grid <- expand.grid(
  "relative_day" = seq(-100, 50),
  "Order" = setdiff(unique(combined$order_top), "other"),
  "subject_" = c("AAA", "AAI")
)

input_data <- partial_dependence_input(X, x_grid)
partial_dependence_write(
  model_paths,
  input_data,
  "data/sandbox/f_bar_rday_model_"
)

###############################################################################
# Study phylogenetic effects
###############################################################################

## Get partial dependence, after averaging out phylogenetic features
x_grid <- expand.grid(
  "phylo_ix" = seq(min(X$phylo_ix), max(X$phylo_ix)),
  "subject_" = c("AAA", "AAI")
)

input_data <- partial_dependence_input(X, x_grid)
partial_dependence_write(
  model_paths,
  input_data,
  "data/sandbox/f_bar_phylo_ix_model_"
)
