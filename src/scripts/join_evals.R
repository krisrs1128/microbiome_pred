#! /usr/bin/env Rscript

## File description -------------------------------------------------------------
## Join all the feathers in the evaluation directory, run from the src/
## directory

library("feather")
f <- list.files(
  "../../data/processed/eval/",
  pattern = ".feather",
  full.names = TRUE
)
metrics <- lapply(f, read_feather)
for (i in seq_along(metrics)) {
  metrics[[i]]$source <- f[i]
}

write.csv(
  do.call(rbind, metrics),
  "../../data/processed/eval/all_metrics.csv",
  row.names = FALSE
)
