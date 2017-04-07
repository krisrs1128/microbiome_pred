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
model_paths <- list.files("data/processed/models/", "*.RData", full.names = TRUE)
ps <- readRDS("data/raw/ps.RDS")
X <- read_feather(X_path)
y <- read_feather(y_path)
models <- lapply(model_paths, function(x) get(load(x)))

combined <- X %>%
  left_join(y) %>%
  gather_dummy("order", "Order") %>%
  gather_dummy("subject", "subject_") %>%
  mutate(
    order_top = recode_rare(order, 7),
    jittered_count = count + runif(n(), 0, 0.5),
    binarized_count = ifelse(count > 0, 0, 1)
  )

###############################################################################
# Study time effects
###############################################################################
p <- ggplot(combined) +
  geom_point(
    aes(x = relative_day, y = jittered_count),
    size = 0.5, alpha = 0.1,
  ) +
  geom_line(
    aes(x = relative_day, y = jittered_count, group = rsv),
    size = 0.3, alpha = 0.1
  ) +
  facet_grid(subject ~ order_top) +
  guides(color = guide_legend(override.aes = list(alpha = 1))) +
  theme(
    panel.border = element_rect(fill = "transparent", size = 0.2)
  )

p <- p +
  xlim(-100, 50)

ggplot(combined %>%
       group_by(subject, relative_day, order_top) %>%
       summarise(
         prop_nonzero = mean(binarized_count),
         prop_lower = max(0, prop_nonzero - 1.96 * sd(binarized_count) / sqrt(n())),
         prop_upper = min(1, prop_nonzero + 1.96 * sd(binarized_count) / sqrt(n()))
       )
       ) +
  geom_point(
    aes(x = relative_day, y = prop_nonzero)
  ) +
  geom_line(
    aes(x = relative_day, y = prop_nonzero),
    alpha = 0.5
  ) +
  geom_errorbar(
    aes(x = relative_day, ymax = prop_upper, ymin = prop_lower)
  ) +
  facet_grid(subject ~ order_top) +
  xlim(-100, 50)

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
