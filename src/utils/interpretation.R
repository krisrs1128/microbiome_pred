
gather_dummy <- function(x, new_var, dummy_prefix) {x %>%
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
