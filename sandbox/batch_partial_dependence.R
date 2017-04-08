
f <- readLines("src/scripts/f_bar.batch")
model_paths <- list.files("data/processed/models/", "all.RData")
feature_types <- c("phylo", "time")

for (i in seq_along(model_paths)) {
  for (j in seq_along(feature_types)) {
    f_new <- c(f, sprintf("Rscript sandbox/write_partial_dependence.R %s %s", model_paths[i], feature_types[j]))
    tmp <- tempfile()
    cat(f_new, file = tmp, sep = "\n")
    system(sprintf("sbatch %s", tmp))
  }
}
