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
## Prepare data
###############################################################################

combined <- X %>%
  left_join(y) %>%
  gather_dummy("order", "Order") %>%
  gather_dummy("subject", "subject_") %>%
  mutate(
    order_top = recode_rare(order, 7),
    jittered_count = count + runif(n(), -0.5, 0.5),
    binarized = ifelse(count > 0, 1, 0),
    jittered_binarized = binarized + runif(n(), -0.1, 0.1)
  )
combined$order <- factor(combined$order, levels = names(sort(table(combined$order), dec = TRUE)))

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

###############################################################################
## Overall order effect
###############################################################################
ggplot(combined) +
  geom_point(
    aes(x = order, y = jittered_count, col = order_top),
    size = 0.3, alpha = 0.2, position = position_jitter(w = 0.1)
  ) +
  geom_point(
    data = f_data[["order"]],
    aes(x = order, y = f_bar, group = ix),
    size = 1.2
  ) +
  facet_grid(subject ~ .)

ggplot(
  combined %>%
  group_by(subject, order, order_top) %>%
  summarise(
    prop_nonzero = mean(binarized),
    prop_lower = max(0, prop_nonzero - 1.96 * sd(binarized) / sqrt(n())),
    prop_upper = min(1, prop_nonzero + 1.96 * sd(binarized) / sqrt(n()))
  )
) +
  geom_point(
    data = combined,
    aes(x = order, y = jittered_binarized, col = order_top),
    size = 0.3, alpha = 0.2, position = position_jitter(w = 0.1)
  ) +
  geom_point(
    aes(x = order, y = prop_nonzero, col = order_top)
  ) +
  geom_errorbar(
    aes(x = order, ymin = prop_lower, ymax = prop_upper, col = order_top)
  ) +
  geom_point(
    data = f_data[["order"]],
    aes(x = order, y = 1 - f_bar)
  ) +
  facet_grid(subject ~ .) +
  theme(
    panel.border = element_rect(fill = "transparent", size = 0.2)
  )

###############################################################################
## Study time effects
###############################################################################

ggplot(combined) +
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
  ) +
  xlim(-100, 50)

ggplot(
  combined %>%
       group_by(subject, relative_day, order_top) %>%
       summarise(
         prop_nonzero = mean(binarized),
         prop_lower = max(0, prop_nonzero - 1.96 * sd(binarized) / sqrt(n())),
         prop_upper = min(1, prop_nonzero + 1.96 * sd(binarized) / sqrt(n()))
       )
       ) +
  geom_point(
    data = combined,
    aes(x = relative_day, y = jittered_binarized, col = order_top),
    alpha = 0.4, size = 0.3
  ) +
  geom_line(
    aes(x = relative_day, y = prop_nonzero, col = order_top),
    size = 0.7
  ) +
  geom_ribbon(
    aes(x = relative_day, ymin = prop_lower, ymax = prop_upper, fill = order_top),
    alpha = 0.5
  ) +
  geom_line(
    data = f_data[["rday"]] %>% filter(ix %in% c(11, 15)),
    aes(x = relative_day, y = 1 - f_bar, group = ix, linetype = method),
    size = 0.7
  ) +
  facet_grid(subject ~ order_top) +
  xlim(-100, 50) +
  theme(
    panel.border = element_rect(fill = "transparent", size = 0.2)
  )

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
ggtree(phy_tree(ps)) %>%
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

ggplot(combined %>%
       group_by(subject, phylo_ix, order_top) %>%
       summarise(
         prop_nonzero = mean(binarized),
         prop_lower = max(0, prop_nonzero - 1.96 * sd(binarized) / sqrt(n())),
         prop_upper = min(1, prop_nonzero + 1.96 * sd(binarized) / sqrt(n()))
       )) +
  geom_point(
    aes(x = phylo_ix, y = prop_nonzero, col = order_top),
    size = 1.2
  ) +
  geom_errorbar(
    aes(x = phylo_ix, ymin = prop_lower, ymax = prop_upper, col = order_top),
    alpha = 0.5
  ) +
  geom_point(
    data = combined,
    aes(x = phylo_ix, y = jittered_binarized, col = order_top),
    size = 0.3, alpha = 0.1
  ) +
  geom_line(
    data = f_data[["phylo_ix"]] %>% filter(ix %in% c(2, 3)),
    aes(x = phylo_ix, y = 1 - f_bar, group = ix, linetype = method)
  ) +
  facet_grid(subject ~ .) +
  theme(
    panel.border = element_rect(fill = "transparent", size = 0.2)
  )

ggplot() +
  geom_point(
    data = combined,
    aes(x = phylo_ix, y = jittered_count, col = order_top),
    size = 0.5, alpha = 0.2
  ) +
  guides(color = guide_legend(override.aes = list(alpha = 1))) +
  geom_line(
    data = f_data[["phylo_ix"]] %>% filter(ix %in% c(4, 5, 6, 7, 8, 9, 10)),
    aes(x = phylo_ix, y = f_bar, group = ix, linetype = method)
  ) +
  facet_grid(subject ~ .) +
  theme(
    panel.border = element_rect(fill = "transparent", size = 0.2)
  )

i = 3
f_data[[i]] %>%
  group_by(ix) %>%
  summarise(max(f_bar))

###############################################################################
## Write data for d3 version
###############################################################################
glimpse(combined)
combined <- combined %>%
  select(-starts_with("phylo_coord"), -count, -binarized)
combined_thinned <- combined[seq(1, nrow(combined), length.out = 7000), ]
library("jsonlite")
cat(
  sprintf("var combined = %s", toJSON(combined_thinned)),
  file = "/Users/krissankaran/Desktop/lab_meetings/20170412/slides/data/combined.js"
)
