#! /usr/bin/env Rscript

## File description -------------------------------------------------------------
## Different error metric functions.

rmse <- function(y, y_hat) {
  sqrt(mean((y - y_hat) ^ 2))
}

mae <- function(y, y_hat) {
  mean(abs(y - y_hat))
}
