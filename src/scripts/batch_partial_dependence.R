
library("readr")
library("plyr")
library("dplyr")

f <- readLines("src/scripts/f_bar.batch")

model_mapping <- read_csv("data/processed/models/models.txt", col_names = FALSE)
colnames(model_mapping) <- c(
  "preprocessing",
  "prop_validation",
  "fold",
  "features",
  "algorithm",
  "basename"
)

model_paths <- model_mapping %>%
  filter(features == "conf/phylo_ix.json") %>%
  mutate(
    path = paste0("/scratch/users/kriss1/programming/research/microbiome_pred/data/processed/models/", basename)
  ) %>%
  select(path) %>%
  unlist()

feature_types <- c(
  "phylo_ix",
  "time",
  "order"
  "phylo_immpost"
)

for (i in seq_along(model_paths)) {
  for (j in seq_along(feature_types)) {
    f_new <- c(f, sprintf("Rscript sandbox/write_partial_dependence.R %s %s", model_paths[i], feature_types[j]))
    tmp <- tempfile()
    cat(f_new, file = tmp, sep = "\n")
    system(sprintf("sbatch %s", tmp))
  }
}
