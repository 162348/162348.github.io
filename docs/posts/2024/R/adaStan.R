library(yuima)
library(glue)
library(rstan)
library(cmdstanr)

rstan_options(auto_write = TRUE)
options(mc.cores = parallel::detectCores())

fetch_data <- function(yuima) {
  variables <- c(
    "int<lower=1> N;",  # N != 0 を Stan でチェック
    "vector[N+1] x;",
    "real<lower=0> T;",
    "real<lower=0> h;"
  )
  snippet <- paste(variables, collapse = "\n")
  return(snippet)
}

fetch_parameters <- function(yuima) {
  params <- yuima@model@parameter@all
  snippet <- paste(" ", "real", params, ";", collapse = "\n")
  return(snippet)
}

fetch_model <- function(yuima) {
  # バグが多いはず
  drift <- gsub("x", "x[1:N]", yuima@model@drift)
  diffusion <- gsub("x", "x[1:N]", yuima@model@diffusion[[1]])  # これも極めて脆弱
  drift <- gsub("mu", "rep_vector(mu, N)", drift)  # 付け焼き刃
  return(list(drift = drift, diffusion = diffusion))
}

fetch_parameters_with_constraints <- function(yuima, parameter_name) {
  # 未完成：sigma など正実数に台を持つパラメータを指定して，それに即した Stan コードを返す
  params <- yuima@model@parameter@all
  if (parameter_name %in% params) {
    params <- params[params != parameter_name]
    snippet <- paste(" ", "real", params, ";", collapse = "\n")
    return(snippet)
  }
  return(fetch_parameters(yuima))
}

stan_templates <- "
data {{
  int N;
  vector[N+1] x;
  real T;
  real h;
}}
parameters {{
  {parameters}
}}
model {{
  x[1] ~ normal(0, 1);
  x[2:(N + 1)] ~ normal(x[1:N] + h * {drift}, sqrt(h) * {diffusion});
}}
"

initialize_yuima <- function(yuima) {
  # To Do: 状態変数を x に変更するコード．
  if ("x" != yuima@model@state.variable) {
    stop("State variable is not 'x'")
  }
}

check_slots <- function(yuima) {
  # To Do: 他のスロットの確認
  if (is.null(yuima@data@original.data)) {
    stop("Data is not available")
  }
}

yuima_to_stan <- function(yuima) {
  initialize_yuima(yuima)

  snippets <- list(
    data = fetch_data(yuima),
    parameters = fetch_parameters(yuima)
  )
  snippets <- append(snippets, fetch_model(yuima))

  return(glue::glue_data(snippets, stan_templates, .trim = FALSE))
}

adaStan <- function(yuima, ..., iter = 1000, chains = 4,
                    refresh = 1000, rstan = TRUE) {
  check_slots(yuima)

  stan_code <- yuima_to_stan(yuima)

  sde_dat <- list(N =  yuima@sampling@n,
                  x = as.numeric(yuima@data@original.data),
                  T = yuima@sampling@Terminal,
                  h = yuima@sampling@Terminal / yuima@sampling@n)

  if (rstan) {
    fit <- stan(model_code = stan_code,
                data = sde_dat,
                iter = iter,
                chains = chains)
  } else {
    stan_file_variables <- write_stan_file(stan_code)
    mod <- cmdstan_model(stan_file_variables)
    fit <- mod$sample(
      data = sde_dat,
      iter_sampling = iter,
      chains = chains,
      refresh = refresh
    )
  }

  return(fit)
}
