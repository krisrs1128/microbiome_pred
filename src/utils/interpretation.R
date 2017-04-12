#! /usr/bin/env Rscript

## File description -------------------------------------------------------------
## Functions to facilitate interpretation of prediction results.

gather_dummy <- function(x, new_var, dummy_prefix) {
  x %>%
    tidyr::gather(new_var, dummy, starts_with(dummy_prefix)) %>%
    dplyr::filter(dummy == 1) %>%
    dplyr::select(-dummy) %>%
    dplyr::mutate(new_var = gsub(dummy_prefix, "", new_var)) %>%
    dplyr::rename_(.dots = setNames("new_var", new_var))
}

recode_rare <- function(x, n_keep) {
  top_levels <- names(sort(table(x), TRUE)[seq_len(n_keep)])
  y <- factor(rep("other", length(x)), levels = c(top_levels, "other"))
  y[x %in% top_levels] <- x[x %in% top_levels]
  y
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
      cat(sprintf("Computing dependence for grid point %s / %s\n", i, n_new))
    }
    xz <- cbind(x[i, ], z)[varnames]
    preds <- try(predict(model, xz, type = "prob")[, 2])
    if (class(pred) == "try-error") {
      preds <- predict(model, xz)
    }
    f_bar[i] <- mean(preds)
  }
  f_bar
}

partial_dependence_input <- function(X, x_grid) {
  library("caret")
  factor_cols <- colnames(x_grid)[sapply(x_grid, is.factor)]
  numeric_cols <- setdiff(colnames(x_grid), factor_cols)
  factor_dummies <- dummyVars("~ .", x_grid[, factor_cols, drop = FALSE]) %>%
    predict(x_grid) %>%
    as_data_frame()
  x <- cbind(x_grid[, numeric_cols, drop = FALSE], factor_dummies) %>%
    as_data_frame()
  colnames(x) <- gsub("\\.", "", colnames(x))

  z <- X %>%
    select_(.dots = setdiff(colnames(X), colnames(x))) %>%
    select(-Meas_ID, -rsv)
  list("x" = x, "z" = z, "x_grid" = x_grid)
}

partial_dependence_write <- function(model, input_data, output_basename) {
  f_bar <- try(partial_dependence(model, input_data$x, input_data$z))
  if (class(f_bar) != "try-error") {
    feather::write_feather(
               cbind(
                 method = model$modelInfo$label,
                 input_data$x_grid,
                 f_bar
               ),
               sprintf("%s.feather", output_basename)
             )
  }
}
