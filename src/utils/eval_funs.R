#! /usr/bin/env Rscript

## File description -------------------------------------------------------------
## Different error metric functions.

rmse <- function(y, y_hat) {
  sqrt(mean((y - y_hat) ^ 2))
}

mae <- function(y, y_hat) {
  mean(abs(y - y_hat))
}

accuracy <- function(y, y_hat) {
  comp <- table(y > 0, y_hat > 0.5) # need to binarize y first
  sum(diag(comp)) / sum(comp)
}

precision_at_k <- function(k) {
  function(y, y_hat) {
    sum(y > 0 & y_hat > (k / 100)) / sum(y_hat > 0)
  }
}

precision_at_95 <- precision_at_k(95)
precision_at_90 <- precision_at_k(90)
precision_at_85 <- precision_at_k(85)
precision_at_80 <- precision_at_k(80)
precision_at_75 <- precision_at_k(75)
precision_at_70 <- precision_at_k(70)
precision_at_65 <- precision_at_k(65)
precision_at_60 <- precision_at_k(60)
precision_at_55 <- precision_at_k(55)
precision_at_50 <- precision_at_k(50)
precision_at_45 <- precision_at_k(45)
