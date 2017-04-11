
library("feather")
library("plyr")
library("dplyr")
library("ggplot2")

eval_paths <- list.files("data/processed/eval", "cv*", full.names = TRUE)
eval_data <- do.call(rbind, lapply(eval_paths, read_feather))
eval_data$model_type <- "full"

eval_data$model_type[grep("pos", eval_data$model_conf)] <- "conditional"
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
  ) %>%
  filter(
    algorithm %in% c("rf", "gbm", "rpart", "glmnet"),
    metric %in% c("rmse", "mae")
  )

algo_order <- eval_data %>%
  filter(metric %in% c("rmse", "mae")) %>%
  group_by(algorithm) %>%
  summarise(value = mean(value)) %>%
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

glimpse(eval_data)
ggplot(eval_data %>% filter(metric %in% c("rmse", "mae"))) +
  geom_point(aes(x = algorithm, y = value, col = model_type)) +
  facet_wrap(~metric, scales = "free_y")

m <- get(load(list.files("data/processed/models", full.names = TRUE)[20]))
m <- get(load(list.files("data/processed/models", full.names = TRUE)[30]))
varImp(m$finalModel)
varImp(m)

imp <- data_frame(
  variable = rownames(m$finalModel$importance),
  value =  m$finalModel$importance[, 1]
) %>%
  arrange(desc(value)) 
imp$variable <- factor(imp$variable, levels = imp$variable)

ggplot(imp) +
  geom_point(aes(x = variable, y = value))
