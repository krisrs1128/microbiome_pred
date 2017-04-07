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
model_paths <- list.files("data/processed/models/", "all.RData", full.names = TRUE)
ps <- readRDS("data/raw/ps.RDS")
X <- read_feather(X_path)
y <- read_feather(y_path)

###############################################################################
# Study time effects
###############################################################################

## Get partial dependence, after averaging out phylogenetic features
x_pre <- expand.grid(
  "relative_day" = seq(-100, 50),
  "Order" = setdiff(unique(combined$order_top), "other"),
  "subject_" = c("AAA", "AAI")
)
x <- model.matrix(relative_day ~ -1 + subject_ + Order, x_pre)
x <- cbind("relative_day" = x_pre$relative_day, x) %>%
  as_data_frame()

z <- X %>%
  select_(.dots = setdiff(colnames(X), colnames(x))) %>%
  select(-Meas_ID)
dir.create("data/sandbox", recursive = TRUE)

for (i in seq_along(model_paths)) {
  cat(sprintf("Computing dependences for model %s\n", i))
  model <- get(load(model_paths[[i]]))
  if (!is.null(model$method)) { ## don't do this for ensemble models
    f_bar <- partial_dependence(model, x, z)
    write_feather(
      cbind(x_pre, f_bar),
      sprintf("data/sandbox/f_bar_rday_model_%s.feather", i)
    )
  }
}

combined <- X %>%
  left_join(y) %>%
  gather_dummy("order", "Order") %>%
  gather_dummy("subject", "subject_") %>%
  mutate(
    order_top = recode_rare(order, 7),
    jittered_count = count + runif(n(), 0, 0.5),
    binarized_count = ifelse(count > 0, 0, 1)
  )

p <- ggplot(combined) +
  geom_point(
    aes(x = relative_day, y = jittered_count),
    size = 0.5, alpha = 0.1,
  ) +
  geom_line(
    aes(x = relative_day, y = jittered_count, group = rsv),
    size = 0.3, alpha = 0.1
  ) +
  geom_line(
    data = cbind(x_pre, f_bar) %>%
      rename(
        order_top = Order,
        subject = subject_
      ),
    aes(x = relative_day, y = f_bar),
    size = 0.3, alpha = 1, col = "purple"
  ) +
  facet_grid(subject ~ order_top) +
  guides(color = guide_legend(override.aes = list(alpha = 1))) +
  theme(
    panel.border = element_rect(fill = "transparent", size = 0.2)
  )

p <- p +
  xlim(-100, 50)

p <- ggplot(combined %>%
       group_by(subject, relative_day, order_top) %>%
       summarise(
         prop_nonzero = mean(binarized_count),
         prop_lower = max(0, prop_nonzero - 1.96 * sd(binarized_count) / sqrt(n())),
         prop_upper = min(1, prop_nonzero + 1.96 * sd(binarized_count) / sqrt(n()))
       )
       ) +
  geom_point(
    aes(x = relative_day, y = prop_nonzero),
    alpha = 0.5
  ) +
  geom_line(
    aes(x = relative_day, y = prop_nonzero),
    alpha = 0.5
  ) +
  geom_errorbar(
    aes(x = relative_day, ymax = prop_upper, ymin = prop_lower),
    alpha = 0.2
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
