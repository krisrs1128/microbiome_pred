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
f_paths <- list.files("data/sandbox/", "f_bar*", full.names = TRUE)[1:6]
ps <- readRDS("data/raw/ps.RDS")
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

f_data <- lapply(f_paths, read_feather)
for (i in seq_along(f_data)) {
  f_data[[i]]$ix <- i
}
cols <- sapply(f_data, colnames)
cols

f_data_phylo <- do.call(rbind, f_data[1:5]) %>%
  rename(subject = subject_)
f_data_time <- do.call(rbind, f_data[6]) %>%
  rename(subject = subject_, order_top = Order)

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
    data = f_data_time %>% filter(ix == 6),
    aes(x = relative_day, y = f_bar, group = ix, col = method),
    size = 0.3, alpha = 1
  ) +
  facet_grid(subject ~ order_top) +
  guides(color = guide_legend(override.aes = list(alpha = 1))) +
  scale_color_brewer(palette = "Set1") +
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
  geom_line(
    data = f_data_time %>% filter(ix == 6),
    aes(x = relative_day, y = 1 - f_bar, group = ix, linetype = method),
    size = 0.3, alpha = 1,
    col = "#F69259"
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

ggplot() +
  geom_errorbar(
    data = combined %>%
      group_by(subject, phylo_ix, order_top) %>%
      summarise(
        prop_nonzero = mean(binarized_count),
        prop_lower = max(0, prop_nonzero - 1.96 * sd(binarized_count) / sqrt(n())),
        prop_upper = min(1, prop_nonzero + 1.96 * sd(binarized_count) / sqrt(n()))
      ),
    aes(x = phylo_ix, ymin = prop_lower, ymax = prop_upper, col = order_top)
  ) +
  geom_line(
    data = f_data_phylo %>% filter(ix %in% c(1, 2, 4)),
    aes(x = phylo_ix, y = 1 - f_bar, group = ix, linetype = method)
  ) +
  facet_grid(subject ~ .)
