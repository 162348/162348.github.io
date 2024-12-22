data {
  int<lower=1> n;  // n = N * J - #(NA responses)
  int<lower=1> N;  // number of judges
  int<lower=1> J;  // number of cases

  array[n] int<lower=0, upper=1> Y;  // response variable
  vector[N] Z;  // covariates for judges
  array[n] int<lower=1, upper=N> i;  // indicator for judges i in [N]
  array[n] int<lower=1, upper=J> j;  // indicator for cases j in [J]
}
parameters {
  vector[N] X;  // ideal points for judges
  vector[J] alpha;
  vector[J] beta;

  real delta;
  real gamma;
}
transformed parameters {
  real lprior = 0;

  lprior += std_normal_lpdf(delta);
  lprior += std_normal_lpdf(gamma);
  lprior += std_normal_lpdf(alpha);
  lprior += std_normal_lpdf(beta);
  lprior += std_normal_lpdf(X);
}
model {
  X ~ normal(delta + Z * exp(gamma), 1);

  vector[n] mu = rep_vector(0, n);
  for (k in 1:n) {
    mu[k] = alpha[j[k]] + beta[j[k]] * X[i[k]];
  }
  target += bernoulli_logit_lpmf(Y | mu);
  target += lprior;
}
