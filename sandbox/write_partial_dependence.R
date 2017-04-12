#! /usr/bin/env Rscript

## File description -------------------------------------------------------------
## Script to get the partial dependence wrt time, subject, and phylogenetic index

args <- commandArgs(trailingOnly = TRUE)
model_path <- args[[1]]
dependence_type <- args[[2]]

library("feather")
library("readr")
library("dplyr")
source("src/utils/interpretation.R")

## create directory, read existing (full) data and models
dir.create("data/sandbox", recursive = TRUE)
x_mapping <- read_csv("data/processed/features/features.txt", col_names = FALSE) %>%
  rename(
    preprocessing = X1,
    prop_validation = X2,
    fold = X3,
    features = X4,
    basename = X5
  )

y_mapping <- read_csv("data/processed/responses/responses.txt", col_names = FALSE)  %>%
  rename(
    preprocessing = X1,
    prop_validation = X2,
    fold = X3,
    basename = X4
  )

x_basename <- x_mapping %>%
  filter(features == "conf/phylo_ix.json") %>%
  select(basename) %>%
  unlist()

X_path <- sprintf("data/processed/features/%s-all.feather", x_basename)
y_path <- sprintf("data/processed/responses/%s-all.feather", y_mapping$basename[1])
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

subjects <- colnames(X)[grep("subject_", colnames(X))]
subjects <- gsub("subject_", "", subjects)

if (dependence_type == "time") {
  ## Get partial dependence, after averaging out phylogenetic features
  x_grid <- expand.grid(
    "relative_day" = seq(-90, 80, length.out = 50),
    "Order" = setdiff(unique(combined$order_top), "other"),
    "subject_" = subjects
  )
  output_base <- "data/sandbox/f_bar_rday_%s"

} else if (dependence_type == "phylo_ix") {
  ## Get partial dependence, after averaging out phylogenetic features
  x_grid <- expand.grid(
    "phylo_ix" = seq(min(X$phylo_ix), max(X$phylo_ix), length.out = 250),
    "subject_" = subjects
  )
  output_base <- "data/sandbox/f_bar_phylo_ix_%s"
} else if (dependence_type == "order") {
  ## Get partial dependence, after averaging everything except order and subject
  x_grid <- expand.grid(
    "Order" = unique(combined$order),
    "subject_" = subjects
  )
  output_base <- "data/sandbox/f_bar_order_%s"
} else if (dependence_type == "phylo_immpost") {
  ## Get partial dependence, after averaging everything except phylogeny, time, and subject
  x_grid <- expand.grid(
    "phylo_ix" = seq(min(X$phylo_ix), max(X$phylo_ix), length.out = 250),
    "imm_post" = c(0, 1),
    "subject_" = subjects
  )
  output_base <- "data/sandbox/f_bar_order_%s"
} else {
  stop(sprintf("Partial dependence type %s not found", dependence_type))
}

input_data <- partial_dependence_input(X, x_grid)
partial_dependence_write(
  get(load(model_path)),
  input_data,
  sprintf(
    output_base,
    basename(tools::file_path_sans_ext(model_path))
  )
)
