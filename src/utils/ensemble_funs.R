#! /usr/bin/env Rscript

## File description -------------------------------------------------------------
## Functions for ensembling across many models, given their predictions and the
## truth across data sets

ensemble_averaging <- function(models_list, preds_list, y_list) {
  model <- list()
  ens_predict <- function(newdata) {
    preds <- list()
    for (m in seq_along(models_list)) {
      preds[[m]] <- predict(models_list[[m]], newdata = newdata)
    }

    all_preds <- do.call(cbind, preds)
    rowMeans(all_preds)
  }
  list("model" = model, "ens_predict" = ens_predict)
}
