
source("src/utils/models.R")
library("caret")
model_base <- c("rf", "xgbTree", "rpart")

for (i in seq_along(model_base)) {
  m0 <- getModelInfo(model_base[i], regex = FALSE)[[1]]
  m <- conditional_positive_model(m0)
  save(m, file = sprintf("conf/%s_pos.RData", model_base[i]))
  m <- binarize_model(m0)
  save(m, file = sprintf("conf/%s_binarize.RData", model_base[i]))
}

# getModelInfo("glmnet", FALSE)[[1]]$grid(as.matrix(x_all %>% select(-rsv, -Meas_ID)), as.numeric(y), 10) %>% toJSON
