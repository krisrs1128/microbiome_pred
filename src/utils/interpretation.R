#! /usr/bin/env Rscript

## File description -------------------------------------------------------------
## Functions to facilitate interpretation of prediction results.

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
  factor(y, c(top_levels, "other"))
}

#' Compute Partial dependence
#'
#' This is the interpretation technique proposed on page 369 of The Elements of
#' Statistical Learning.
#'
#' @param model [model] A model with a predict method, whose functional form we
#'   want to investigate.
#' @param x [data.frame] A data.frame of new points to compute predictions on,
#'   after accounting for the effects from z. The column names must be contained
#'   in set of variable names used when training the model.
#' @param z [data.frame] The original data.frame used to train the model, after
#'   subtracting out the variables in x.
#' @return f_bar [numeric] The estimated partial dependence effect of the
#'   response on x, after acounting for z.
partial_dependence <- function(model, x, z) {
  n_new <- nrow(x)
  n <- nrow(z)
  varnames <- colnames(model$call$x)
  f_bar <- vector(length = n_new)

  for (i in seq_len(n_new)) {
    if (i %% 10 == 0) {
      cat(sprintf("Computing dependence for grid point %s\n", i))
    }
    xz <- cbind(x[i, ], z)[varnames]
    f_bar[i] <- mean(predict(model, xz))
  }
  f_bar
}
