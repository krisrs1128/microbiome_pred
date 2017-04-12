#! /usr/bin/env Rscript

## File description -------------------------------------------------------------
## User-specified models, input to caret using the method described
## https://topepo.github.io/caret/using-your-own-model-in-train.html

#' Train a model on only positive responses
#'
#' A natural approach to prediction when there are many responses that are zero
#' is to take a two step "hurdle" approach. This modifies any blackbox caret
#' model fit function so that it only fits on the positive response values.
#'
#' @param fit_fun [function] The fit function, obtained from
#'   getModelInfo("modelname")$fit, for example.
#' @return [function] A modified fitting function.
conditional_positive_fit <- function(fit_fun) {
  function(x, y, wts, param, lev, last, classProbs, ...) {
    pos_ix <- y > 0
    res <- fit_fun(x[pos_ix, ], y[pos_ix], wts, param, lev, last, classProbs, ...)
    res
  }
}

#' Modify caret::getModelInfo to work with Nonnegative Response
#'
#' This is a convenience wrapper for conditional_positive_fit that keeps all the
#' model info in place except for the $fit method, which is replaced by a
#' conditional positive version.
#'
#' @param model_info [list] A list with names corresponding to output from
#'   getModelInfo() in caret.
#' @return new_model_info [list] A list identical to model_info, but with a new
#'   fit component.
#'
#' @examples
#' X <- matrix(rnorm(100 * 10), 100, 10)
#' y <- X %*% rnorm(10, 0, 3) + rnorm(100, 0, 0.05)
#' y <- y + abs(min(y))
#' y <- as.numeric(y)
#' y[1:40] <- 0
#'
#' lm_fit <- train(x = X, y = y, method = "lm")
#' pos_lm <- conditional_positive_model(getModelInfo("lm", regex = FALSE)[[1]])
#' pos_lm_fit <- caret::train(x = X, y = y, method = pos_lm)
#'
#' y_hat <- predict(lm_fit, X)
#' y_hat_pos <- predict(pos_lm_fit, X)
#'
#' plot(y, y_hat, asp = 1)
#' points(y, y_hat_pos, col = "red", asp = 1)
#' abline(0, 1)
conditional_positive_model <- function(model_info) {
  new_model_info <- model_info
  new_model_info$fit <- conditional_positive_fit(model_info$fit)
  new_model_info$label <- paste0("conditional_", model_info$label)
  new_model_info
}

binarize_fit <- function(fit_fun, threshold = 0) {
  function(x, y, wts, param, lev, last, classProbs, ...) {
    fit_fun(x, as.factor(y > threshold), wts, param, lev, last, classProbs, ...)
  }
}

binarize_model <- function(model_info) {
  new_model_info <- model_info
  new_model_info$fit <- binarize_fit(model_info$fit)
  new_model_info$label <- paste0("binarize_", model_info$label)
  new_model_info
}
