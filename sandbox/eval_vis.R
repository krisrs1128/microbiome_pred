
library("feather")
library("plyr")
library("dplyr")
library("ggplot2")
theme_set(ggscaffold::min_theme())

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

eval_data$model_type <- "full"
eval_data$model_type[grep("conditional", eval_data$model_conf)] <- "conditional"
eval_data$model_type[grep("binarize", eval_data$model_conf)] <- "binarized"

prec <- eval_data %>%
  filter(metric == "precision_at_90") %>%
  filter(model_type == "binarized") %>%
  select(value) %>%
  unlist()

eval_data <- eval_data %>%
  mutate(
    algorithm = gsub("conf/||.json||_conditional||_binarize", "", model_conf)
  ) %>%
  filter(
    algorithm %in% c("rf", "xgbTree", "rpart", "glmnet")
  )

algo_order <- eval_data %>%
  filter(metric %in% c("rmse", "mae")) %>%
  group_by(algorithm) %>%
  dplyr::summarise(value = mean(value)) %>%
  arrange(value) %>%
  select(algorithm) %>%
  unlist()

read_feather("data/processed/responses/responses_616901990044369-all.feather") %>%
  select(count) %>%
  unlist() %>%
  sd()

eval_data$algorithm <- factor(
  eval_data$algorithm,
  levels = algo_order
)

ggplot(eval_data %>% filter(metric %in% c("rmse", "mae"))) +
  geom_point(aes(x = algorithm, y = value, col = model_type)) +
  facet_wrap(~metric, scales = "free_y")

models <- model_mapping %>%
  group_by(features_conf) %>%
  do(data.frame(.$basename))

models_split <- dlply(model_mapping, .(features_conf), function(x) x$basename)
models <- list()
for (i in seq_along(models_split)) {
  models[[i]] <- lapply(
    models_split[[i]],
    function(x) get(load(file.path("data/processed/models", x)))
  )
  names(models[[i]]) <- models_split[[i]]
}
names(models) <- names(models_split)


imp <- lapply(models[[1]], function(x) { try(data.frame(t(varImp(x)$importance))) })
names(imp) <- names(models[[1]])
imp <- imp[sapply(imp, is.data.frame)]
imp_df <- do.call(rbind.fill, imp)
imp_df$basename<- names(imp)

imp_df <- imp_df %>%
  left_join(model_mapping) %>%
  left_join(eval_data %>% select(-metric, -value, -cur_fold) %>% unique) %>%
  tidyr::gather(feature, value, -basename, -preprocess_conf, -validation_prop, -k_folds, -features_conf, -model_conf, -algorithm, -model_type) %>%
  unique()

feature_order <- imp_df %>%
  group_by(feature) %>%
  dplyr::summarise(value = median(value)) %>%
  arrange(desc(value)) %>%
  select(feature) %>%
  unlist()

imp_df$feature <- factor(imp_df$feature, levels = feature_order)

ggplot(imp_df %>% filter(feature %in% feature_order[1:10])) +
  geom_point(
    aes(x = feature, y = value, col = model_type)
  ) +
  scale_color_brewer(palette = "Set1") +
  facet_wrap(~algorithm, scale = "free_x")

y_hat <- read_feather("data/processed/preds/preds_638015165712378-all.feather")
y <- read_feather("data/processed/responses/responses_423987532140068-all.feather")
plot(y, y_hat)
