number_of_experiments <- 500

library(rstan)
library(ggplot2)
library(MCMCpack)
data(Rehnquist)
library(tidyverse)

df <- Rehnquist %>%
  # データを長形式に変換
  pivot_longer(cols = -c(term, time), names_to = "name", values_to = "y") %>%
  # ケース ID を追加
  mutate(case = (row_number() - 1) %/% 9 + 1)
df <- df %>%
  mutate(
    nominator = case_when(
      name %in% c("Rehnquist", "Stevens") ~ "Nixon",
      name %in% c("O.Connor", "Scalia", "Kennedy") ~ "Reagan",
      name %in% c("Souter", "Thomas") ~ "Bush",
      name %in% c("Breyer", "Ginsburg") ~ "Clinton"
    )
  )
df$x <- ifelse(
  df$nominator %in% c("Nixon", "Reagan", "Bush", "Trump"),
  1, -1)

case_number <- as.integer(nrow(df) / 9)
indicator_i <- rep(1:9, times = case_number)
indicator_j <- rep(1:case_number, each = 9)
df$i <- indicator_i
df$j <- indicator_j

df_NA <- df %>% filter(!is.na(y))

data <- list(Y = df_NA$y, n = nrow(df_NA), N = 9, J = case_number, Z = df_NA$x[1:9], i = df_NA$i, j = df_NA$j)

save(data, file = "data.rdata")

count <- 0

for (i in 1:number_of_experiments) {
  fit <- stan("bafumi.stan", data = data, chains = 4, cores = 4, verbose = TRUE, iter = 4000, warmup = 3000)

  all_samples <- rstan::extract(fit, pars = "X")$X
  last_1000_samples <- all_samples[(nrow(all_samples) - 999):nrow(all_samples), ]
  mean <- apply(last_1000_samples, 2, mean)
  if (mean[9] > 0.5) {
    count <- count + 1
    print("Ouch!")
  }
}
print(count)
  #     lower = apply(last_1000_samples, 2, quantile, probs = 0.025),
  #     upper = apply(last_1000_samples, 2, quantile, probs = 0.975)
  # )
  # title <- paste0("Elapsed time: ", execution_time, " seconds")
  # p <- ggplot(plot_dataframe, aes(x = mean, y = legislator)) +
  #     geom_point() +
  #     geom_errorbar(aes(xmin = lower, xmax = upper), width = 0.2) +
  #     theme(axis.text.x = element_text(angle = 90, hjust = 1)) +
  #     labs(x = "Mean", y = "Legislator", title = title)
  # ggsave(paste0("Files/experiment_", i, ".png"), p)
save(count, file = "experiment.rdata")