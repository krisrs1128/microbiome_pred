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
f_paths <- list.files("data/sandbox/", "f_bar*", full.names = TRUE)
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

f_list <- lapply(f_paths, read_feather)
for (i in seq_along(f_list)) {
  f_list[[i]]$ix <- i
  f_list[[i]] <- f_list[[i]] %>%
    rename(subject = subject_)

  if ("Order" %in% colnames(f_list[[i]])) {
    f_list[[i]] <- f_list[[i]] %>%
      rename(order = Order) %>%
      mutate(order_top = recode_rare(order, 7))
  }

  if (grepl("phylo_ix", f_paths[[i]])) {
    f_list[[i]]$type <- "phylo_ix"
  } else if (grepl("order", f_paths[[i]])) {
    f_list[[i]]$type <- "order"
  } else if (grepl("rday", f_paths[[i]])) {
    f_list[[i]]$type <- "rday"
  }
}

types <- sapply(f_list, function(x) x$type[1])
unique_types <- unique(types)
f_data <- list()
for (i in seq_along(unique_types)) {
  f_data[[unique_types[[i]]]] <- do.call(rbind, f_list[types == unique_types[i]])
}

p <- ggplot(combined) +
  geom_point(
    aes(x = relative_day, y = jittered_count, col = order_top),
    size = 0.5, alpha = 0.1,
  ) +
  geom_line(
    aes(x = relative_day, y = jittered_count, group = rsv, col = order_top),
    size = 0.3, alpha = 0.1
  ) +
  geom_line(
    data = f_data[["rday"]] %>% filter(ix %in% c(12, 13, 15)),
    aes(x = relative_day, y = f_bar, group = ix, linetype = method),
    size = 0.7, alpha = 1
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
    aes(x = relative_day, y = prop_nonzero, col = order_top),
    alpha = 0.6
  ) +
  geom_line(
    aes(x = relative_day, y = prop_nonzero, col = order_top),
    alpha = 0.6
  ) +
  geom_line(
    aes(x = relative_day, y = prop_upper, col = order_top),
    alpha = 0.4, linetype = 2
  ) +
  geom_line(
    aes(x = relative_day, y = prop_lower, col = order_top),
    alpha = 0.4, linetype = 2
  ) +
  geom_line(
    data = f_data[["rday"]] %>% filter(ix %in% c(11, 15)),
    aes(x = relative_day, y = 1 - f_bar, group = ix, linetype = method),
    size = 0.3, alpha = 1
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
ggplot(f_data_time %>% filter(ix %in% c(11, 12, 13, 15))) +
  geom_bar(aes(x = relative_day, y = f_bar, fill = order_top),
           stat = "identity", position = "dodge") +
  facet_grid(subject ~ ix)

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
    data = f_data_phylo %>% filter(ix %in% c(1, 2)),
    aes(x = phylo_ix, y = 1 - f_bar, group = ix, linetype = method)
  ) +
  facet_grid(subject ~ .)

ggplot() +
  geom_point(
    data = combined,
    aes(x = phylo_ix, y = count, col = order_top),
    size = 0.5, alpha = 0.2
  ) +
  geom_line(
    data = f_data_phylo %>% filter(ix %in% c(4)),
    aes(x = phylo_ix, y = f_bar, group = ix, linetype = method)
  ) +
  facet_grid(subject ~ .)
