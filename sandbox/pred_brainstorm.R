#! /usr/bin/env Rscript

## File description -------------------------------------------------------------
## Some experiments with visualizing the predictions from various models we've
## tried.

library("readr")
library("feather")
library("plyr")
library("dplyr")
library("tidyr")
library("ggplot2")
library("ggtree")
library("phyloseq")
library("jsonlite")
source("src/utils/interpretation.R")
theme_set(ggscaffold::min_theme())

scale_colour_discrete <- function(...)
  scale_color_brewer(palette = "Set2", ...)
scale_fill_discrete <- function(...)
  scale_fill_brewer(palette = "Set2", ...)

data_path <- file.path("data", "processed")
x_mapping <- read_csv(
  file.path(data_path, "features", "features.txt"),
  col_names = FALSE
)

y_mapping <- read_csv(
  file.path(data_path, "responses", "responses.txt"),
  col_names = FALSE
)

model_mapping <- read_csv(
  file.path(data_path, "models", "models.txt"),
  col_names = FALSE
)
colnames(model_mapping) <- c(
  "preprocess_conf",
  "validation_prop",
  "k_folds",
  "features_conf",
  "model_conf",
  "basename"
)

cur_x_base <- x_mapping %>%
  filter(
    X1 == "conf/subsample_subject.json",
    X2 == 0.2,
    X3 == 3,
    X4 == "conf/phylo_ix.json"
  ) %>%
  select(X5) %>%
  unlist()

## Not the cv-fold data
X_path <- file.path(data_path, "features", sprintf("%s-all.feather", cur_x_base))
y_path <- file.path(data_path, "responses", sprintf("%s-all.feather", y_mapping$X4[1]))
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

library("stringr")
f_paths <- data_frame(path = f_paths) %>%
  mutate(
    basename = str_extract(path, "model_[0-9\\-\\.A-z]+")
  ) %>%
  mutate(
    basename = gsub("feather", "RData", basename)
  ) %>%
  left_join(model_mapping)

f_list <- lapply(f_paths$path, read_feather)

for (i in seq_along(f_list)) {
  f_list[[i]]$ix <- i

  if (grepl("_", f_list[[i]]$method[1])) {
    f_list[[i]] <- f_list[[i]] %>%
      separate(method, c("model_type", "algorithm"), sep = "_")
  } else {
    f_list[[i]]$model_type <- "full"
    f_list[[i]]$algorithm <- f_list[[i]]$method
  }

  if ("subject_" %in% colnames(f_list[[i]])) {
    f_list[[i]] <- f_list[[i]] %>%
      rename(subject = subject_)
  }

  if ("Order" %in% colnames(f_list[[i]])) {
    f_list[[i]] <- f_list[[i]] %>%
      rename(order = Order) %>%
      mutate(order_top = recode_rare(order, 7))
  }

  if ("imm_post" %in% colnames(f_list[[i]])) {
    f_list[[i]]$type <- "phylo_immpost"
  } else if (grepl("phylo_ix", f_paths$path[i])) {
    f_list[[i]]$type <- "phylo_ix"
  } else if (grepl("order", f_paths$path[i])) {
    f_list[[i]]$type <- "order"
  } else if (grepl("rday", f_paths$path[i])) {
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
## Write data for d3 version
###############################################################################
glimpse(combined)
keep_rsvs <- sample(unique(combined$rsv), 50)
combined_thinned <- combined %>%
  select(-starts_with("phylo_coord"), -count, -binarized) %>%
  filter(rsv %in% keep_rsvs) %>%
  arrange(rsv, relative_day)
combined_thinned$order <- droplevels(combined_thinned$order)
combined_thinned$order_top <- droplevels(combined_thinned$order_top)

output_base <- "/Users/krissankaran/Desktop/lab_meetings/20170412/slides/data/"
cat(
  sprintf("var combined = %s", toJSON(combined_thinned)),
  file = file.path(output_base, "combined.js")
)

combined_rsv <- dlply(combined_thinned, c("rsv", "subject"))
names(combined_rsv) <- NULL
cat(
  sprintf("var rsv = %s", toJSON(combined_rsv, auto_unbox = TRUE)),
  file = file.path(output_base, "rsv.js")
)

cat(
  sprintf("var order_levels = %s", toJSON(levels(combined_thinned$order))),
  file = file.path(output_base, "order_levels.js")
)

cat(
  sprintf("var order_top_levels = %s", toJSON(levels(combined_thinned$order_top))),
  file = file.path(output_base, "order_top_levels.js")
)

f_combined <- list()
for (var_type in c("phylo_ix", "phylo_immpost", "order", "rday")) {
  if ("order" %in% colnames(f_data[[var_type]])) {
    f_data[[var_type]] <- f_data[[var_type]] %>%
      filter(order %in% levels(combined_thinned$order))
  }
  if (var_type != "rday") {
    cur_f <- dlply(f_data[[var_type]], c("ix", "subject"))
  } else {
    cur_f <- dlply(f_data[[var_type]], c("ix", "subject", "order_top"))
  }
  names(cur_f) <- NULL
  f_combined[[var_type]] <- cur_f
}

cat(
  sprintf("var f_combined = %s", toJSON(f_combined)),
  file = file.path(output_base, "f_combined.js")
)

###############################################################################
## Overall order effect
###############################################################################
ggplot(combined) +
  geom_point(
    aes(x = order, y = jittered_count, col = order_top),
    size = 0.3, alpha = 0.2, position = position_jitter(w = 0.1)
  ) +
  geom_point(
    data = f_data[["order"]] %>% filter(model_type == "conditional"),
    aes(x = order, y = f_bar, group = ix),
    size = 1.2, alpha = 0.6
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
    data = f_data[["order"]] %>% filter(model_type == "binarize"),
    aes(x = order, y = f_bar)
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
    data = f_data[["rday"]] %>% filter(model_type == "conditional"),
    aes(x = relative_day, y = f_bar, group = ix, linetype = algorithm),
    size = 0.7, alpha = 0.6
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
    data = f_data[["rday"]] %>% filter(model_type == "binarize"),
    aes(x = relative_day, y = f_bar, group = ix, linetype = algorithm),
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
    data = f_data[["phylo_ix"]] %>% filter(model_type == "binarize"),
    aes(x = phylo_ix, y = f_bar, group = ix, linetype = algorithm)
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
    data = f_data[["phylo_ix"]] %>% filter(model_type == "conditional"),
    aes(x = phylo_ix, y = f_bar, group = ix, linetype = algorithm)
  ) +
  facet_grid(subject ~ .) +
  theme(
    panel.border = element_rect(fill = "transparent", size = 0.2)
  )
