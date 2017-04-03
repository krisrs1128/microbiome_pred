library("feather")
library("feather")
library("dplyr")
library("tidyr")
library("ggscaffold")
scale_colour_discrete <- function(...)
  scale_color_brewer(palette = "Set2", ...)
scale_fill_discrete <- function(...)
  scale_fill_brewer(palette = "Set2", ...)

theme_set(min_theme())
x_all <- read_feather("data/processed/features/features_772570831040539-test-all-cv.feather")
y_all <- read_feather("data/processed/responses/responses_616901990044369-test-all-cv.feather")

gather_dummy <- function(x, new_var, dummy_prefix) {
  x %>%
    gather(new_var, dummy, starts_with(dummy_prefix)) %>%
    filter(dummy == 1) %>%
    select(-dummy) %>%
    mutate(new_var = gsub(dummy_prefix, "", new_var)) %>%
    rename_(.dots = setNames("new_var", new_var))
}

recode_rare <- function(x, n_keep) {
  top_levels <- names(sort(table(x), TRUE)[seq_len(n_keep)])
  y <- rep("other", length(x))
  y[x %in% top_levels] <- x[x %in% top_levels]
  y
}

combined <- x_all %>%
  full_join(y_all) %>%
  gather_dummy("family", "Family")  %>%
  gather_dummy("order", "Order") %>%
  gather_dummy("subject", "subject_")

combined <- combined %>%
  mutate(
    order_top = recode_rare(order, 7),
    family_top = recode_rare(family, 7)
  )
ggplot(combined) +
  geom_point(aes(x = phylo_coord_1, y = count, col = order_top)) +
  facet_wrap(~subject)
ggplot(combined) +
  geom_point(aes(x = phylo_coord_1, y = count, col = family_top)) +
  facet_wrap(~subject)
ggplot(combined) +
  geom_point(aes(x = phylo_coord_2, y = count, col = family_top)) +
  facet_wrap(~subject)
ggplot(combined) +
  geom_point(aes(x = phylo_coord_3, y = count, col = family_top)) +
  facet_wrap(~subject)
