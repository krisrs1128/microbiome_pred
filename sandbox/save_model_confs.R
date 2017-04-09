
source("src/utils/models.R")
library("caret")
m <- conditional_positive_model(getModelInfo("rf", regex <- FALSE)[[1]])
save(m, file = "conf/rf_pos.RData")
m <- conditional_positive_model(getModelInfo("glmnet", regex <- FALSE)[[1]])
save(m, file = "conf/glmnet_pos.RData")
m <- conditional_positive_model(getModelInfo("xgbTree", regex <- FALSE)[[1]])
save(m, file = "conf/gbm_pos.RData")

m <- binarize_model(getModelInfo("rf", regex <- FALSE)[[1]])
save(m, file = "conf/rf_binarize.RData")
m <- binarize_model(getModelInfo("glmnet", regex <- FALSE)[[1]])
save(m, file = "conf/glmnet_binarize.RData")
m <- binarize_model(getModelInfo("xgbTree", regex <- FALSE)[[1]])
save(m, file = "conf/gbm_binarize.RData")

# getModelInfo("glmnet", FALSE)[[1]]$grid(as.matrix(x_all %>% select(-rsv, -Meas_ID)), as.numeric(y), 10) %>% toJSON
