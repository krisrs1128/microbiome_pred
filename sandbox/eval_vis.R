
library("feather")
library("plyr")
library("dplyr")
library("ggplot2")

model_mapping <- read_csv("data/processed/models/models.txt", col_names = FALSE)
colnames(model_mapping) <- c(
  "preprocess_conf",
  "validation_prop",
  "k_folds",
  "features_conf",
  "model_conf",
  "basename"
)

eval_paths <- list.files("data/processed/eval", "cv*", full.names = TRUE)
eval_data <- do.call(rbind, lapply(eval_paths, read_feather))
eval_data <- eval_data %>%
  left_join(model_mapping) %>%
  glimpse()

eval_data$model_type <- "full"
eval_data$model_type[grep("conditional", eval_data$model_conf)] <- "conditional"
eval_data$model_type[grep("binarize", eval_data$model_conf)] <- "binarized"

prec <- eval_data %>%
  filter(metric == "precision_at_90") %>%
  filter(model_type == "binarized") %>%
  select(value) %>%
  unlist()

hist(prec)

eval_data <- eval_data %>%
  mutate(
    algorithm = gsub("conf/||.json||_pos||_binarize", "", model_conf)
  )

algo_order <- eval_data %>%
  filter(metric %in% c("rmse", "mae")) %>%
  group_by(algorithm) %>%
  summarise(value = mean(value)) %>%
  arrange(value) %>%
  select(algorithm) %>%
  unlist()

eval_data$algorithm <- factor(
  eval_data$algorithm,
  levels = algo_order
)

glimpse(eval_data)
ggplot(eval_data %>%
       filter(
         metric %in% c("rmse", "mae", "conditional_rmse", "conditional_mae"),
         model_type != "binarized"
       )) +
  geom_point(aes(x = algorithm, y = value, col = model_type)) +
  facet_wrap(~metric, scales = "free_y")

model_mapping
ggplot(imp) +
  geom_point(aes(x = variable, y = value))
