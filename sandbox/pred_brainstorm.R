#! /usr/bin/env Rscript

## File description -------------------------------------------------------------
## Some experiments with visualizing the predictions from various models we've
## tried.

library("feather")
library("dplyr")
library("tidyr")
library("ggplot2")
library("ggtree")
library("phyloseq")
source("src/utils/interpretation.R")
theme_set(ggscaffold::min_theme())

scale_colour_discrete <- function(...)
  scale_color_brewer(palette = "Set2", ...)
scale_fill_discrete <- function(...)
  scale_fill_brewer(palette = "Set2", ...)

## Not the cv-fold data
X_path <- "data/processed/features/features_772570831040539-all.feather"
y_path <- "data/processed/responses/responses_616901990044369-all.feather"
model_paths <- c(
  "data/processed/responses/",
  "data/processed/responses/"
  )
ps <- readRDS("data/raw/ps.RDS")
X <- read_feather(X_path)
y <- read_feather(y_path)
models <- lapply(model_paths, get(load))

combined <- X %>%
  left_join(y) %>%
  gather_dummy("family", "Family")  %>%
  gather_dummy("order", "Order") %>%
  gather_dummy("subject", "subject_") %>%
  mutate(
    order_top = recode_rare(order, 7),
    family_top = recode_rare(family, 7),
    jittered_count = count + runif(n(), 0, 0.2)
  )

###############################################################################
# Study time effects
###############################################################################
p <- ggplot(combined) +
  geom_point(
    aes(x = relative_day, y = jittered_count, col = order_top),
    size = 0.5, alpha = 0.2,
  ) +
  geom_line(
    aes(x = relative_day, y = jittered_count, col = order_top, group = rsv),
    size = 0.5, alpha = 0.1
  ) +
  facet_grid(. ~ subject, scale = "free_x") +
  guides(color = guide_legend(override.aes = list(alpha = 1)))

p <- p +
  xlim(-15, 15)

###############################################################################
# Compare predicted vs. true histograms
###############################################################################
ggplot(combined) +
  geom_histogram(aes(x = jittered_count, fill = order_top)) +
  facet_grid(order_top ~ subject, scale = "free_y") +
  theme(strip.text.y = element_blank())
y_hat <- lapply(models, predict) %>%
  cbind()

###############################################################################
# Study predictions along tree
###############################################################################
p <- ggtree(phy_tree(ps)) %>%
  facet_plot(
    "phylo_ix_early",
    data = combined %>%
      select(-Meas_ID) %>%
      filter(relative_day < -10, subject == "AAI"),
    geom = geom_point,
    aes(x = jittered_count, y = y, col = order_top),
    size = 0.4, alpha = 0.6
  ) %>%
  facet_plot(
    "phylo_ix_mid",
    data = combined %>%
      select(-Meas_ID) %>%
      filter(relative_day > -10, relative_day < 10, subject == "AAI"),
    geom = geom_point,
    aes(x = jittered_count, y = y, col = order_top),
    size = 0.4, alpha = 0.6
  ) %>%
  facet_plot(
    "phylo_ix_late",
    data = combined %>%
      select(-Meas_ID) %>%
      filter(relative_day > 10, subject == "AAI"),
    geom = geom_point,
    aes(x = jittered_count, y = y, col = order_top),
    size = 0.4, alpha = 0.6
  )
