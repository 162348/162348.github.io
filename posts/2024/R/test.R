source("adaStan.R")

model <- setModel(drift = "theta*(mu-x)", diffusion = "sigma", state.variable = "x", solve.variable = "x")
sampling <- setSampling(Initial = 0, Terminal = 3, n = 1000)
yuima <- setYuima(model = model, sampling = sampling)
simulation <- simulate(yuima, true.parameter = c(theta = 1, mu = 0, sigma = 0.5), xinit = rnorm(1))

yuima_to_stan(simulation)
adaStan(simulation)