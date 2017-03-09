library("ggplot2")
library("plyr")
library("dplyr")
library("ggscaffold")
theme_set(min_theme())
getwd()
fit <- get(load("data/processed/models/model_186784021346493-all.RData"))

str(fit)
x <- seq(-150, 150)
y_relative_day <- predict(fit, newdata = data.frame(relative_day = x))
png()
plot(x, y_relative_day)
dev.off()

ps <- readRDS("data/raw/ps.RDS")
y_avg <- data.frame(
  mean = asinh(get_taxa(ps)) %>% rowMeans(),
  sample_data(ps)
)
y_avg$low_read <- y_avg$mean < .1

p <- ggplot(y_avg) +
  geom_point(aes(x = CC_RelDay, y = mean, col = low_read)) +
  facet_wrap(~Subject, scale = "free_x")
ggsave("cc_subject_means.png", p)

y_avg %>%
  filter(mean < .1) %>%
  select(Meas_ID)

y_avg %>%
  arrange(mean) %>%
  head() 
