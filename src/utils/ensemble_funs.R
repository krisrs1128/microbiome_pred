#! /usr/bin/env Rscript

## File description -------------------------------------------------------------
## Functions for ensembling across many models, given their predictions and the
## truth across data sets

ensemble_averaging <- function(models_list, preds_list, y_list) {
  structure(
    list("models_list" = models_list),
    class = "ensemble_averaging"
  )
}

predict.ensemble_averaging <- function(x, newdata) {
  preds <- list()
  for (m in seq_along(x$models_list)) {
    preds[[m]] <- predict(x$models_list[[m]], newdata = newdata)
  }

  all_preds <- do.call(cbind, preds)
  rowMeans(all_preds)
}
