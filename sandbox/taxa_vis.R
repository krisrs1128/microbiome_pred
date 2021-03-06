library("feather")
library("dplyr")
library("tidyr")
library("ggplot2")
library("ggscaffold")
library("ggtree")
library("phyloseq")
source("src/utils/interpretation.R")

scale_colour_discrete <- function(...)
  scale_color_brewer(palette = "Set2", ...)
scale_fill_discrete <- function(...)
  scale_fill_brewer(palette = "Set2", ...)

theme_set(min_theme())
x_all <- read_feather("data/processed/features/features_534790070096521-test-all-cv.feather")
y_all <- read_feather("data/processed/responses/responses_423987532140068-test-all-cv.feather")
ps <- readRDS("data/raw/ps.RDS")

combined <- x_all %>%
  full_join(y_all) %>%
  gather_dummy("order", "Order") %>%
  gather_dummy("subject", "subject_")

combined <- combined %>%
  mutate(
    order_top = recode_rare(order, 7),
    family_top = recode_rare(family, 7)
  )

phylo_ix <- combined %>%
  select(rsv, phylo_ix, count, relative_day) %>%
  unique() %>%
  rename(id = rsv)

p <- ggtree(
  phy_tree(ps)
) +
  xlim_tree(0.3)

facet_plot(
  p,
  panel = "phylo_ix",
  data = phylo_ix,
  geom = geom_point,
  aes(x = count, y = y, col = relative_day),
  position = position_jitter(w = 0.2),
  size = 1,
  alpha = 0.2
) +
  theme_tree2() +
  scale_color_gradient2(low = "#55BDA3", mid = "black")
