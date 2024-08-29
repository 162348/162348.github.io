include("_ZigZagSubsampling_Experiment.jl")

using AdvancedHMC, AdvancedMH, ForwardDiff
using LogDensityProblems
using LogDensityProblemsAD
using StructArrays
using LinearAlgebra

struct LogTargetDensity
    y::Vector{Float64}
end

# LogDensityProblems.logdensity(p::LogTargetDensity, ξ) = -U(ξ, p.x, p.y)
# LogDensityProblems.dimension(p::LogTargetDensity) = 1
# LogDensityProblems.capabilities(::Type{LogTargetDensity}) = LogDensityProblems.LogDensityOrder{1}()
# function LogDensityProblems.logdensity_and_gradient(p::LogTargetDensity)
#     logdens = -U(ξ, p.x, p.y)
#     grad = p.x/ρ^2 + (length(p.y)/σ^2) * (p.x - mean(p.y)) 
#     logdens, grad
# end

function U(i, x, y)
    x[1] * x[1] / (2 * ρ^2) + length(y) * (x[1] - y[i]) * (x[1] - y[i]) / (2 * σ^2)  # 自動微分のために x は長さ1のベクトルと扱う必要がある
end

function U(x, y)
    vec = [U(i, x, y) for i in 1:length(y)]
    return mean(vec)
end

LogDensityProblems.logdensity(p::LogTargetDensity, x) = U(x, p.y)
LogDensityProblems.dimension(p::LogTargetDensity) = 1
LogDensityProblems.capabilities(::Type{LogTargetDensity}) = LogDensityProblems.LogDensityOrder{1}() # 自動微分を回避

function LogDensityProblems.logdensity_and_gradient(p::LogTargetDensity, x)
    logdens = U(x, p.y)
    grad = ∇U1(x)
    logdens, grad
end

# model_with_ad = LogDensityProblemsAD.ADgradient(Val(:ForwardDiff), LogTargetDensity(y1))

model_with_ad = LogTargetDensity(y1)

σ² = 0.05
spl = MALA(x -> MvNormal((σ² / 2) .* x, σ² * I))

chain = sample(model_with_ad, spl, 10000; initial_params=[x0], chain_type=StructArray, param_names=["x"], stats=true)

traj_MALA = Vector{Float64}(chain.x)

epoch_list = [10.0, 100.0, 1000.0, 10000.0]
N = 10

function experiment_MALA(epoch_list, N, y)
    SE_sum = zero(epoch_list)
    for _ in 1:N
        chain = sample(model_with_ad, spl, Int64(epoch_list[end]); initial_params=[x0], chain_type=StructArray, param_names=["x"], stats=true)
        traj_MALA = Vector{Float64}(chain.x)
        SE_list = []
        for T in epoch_list
            SE = SquaredError(traj_MALA[1:T], y)
            push!(SE_list, SE)
        end
        SE_sum += SE_list
    end
    return SE_sum ./ N
end

function experiment(epoch_list, T, dt, N, ∇U, x0, θ0, y, Sampler; ab=ab_ZZ_n1)
    SE_sum = zero(epoch_list)
    acc_list = []
    for _ in 1:N
        trace_ZZ1, epochs_ZZ1, acc_ZZ1 = Sampler(∇U, x0, θ0, T, y, ZigZag1d(); ab=ab)
        push!(acc_list, acc_ZZ1)
        traj_ZZ1 = discretize(trace_ZZ1, ZigZag1d(), dt)
        SE_list = []
        for T in epoch_list
            epoch = findfirst(x -> x > T, epochs_ZZ1) - 1
            t = findfirst(x -> x > trace_ZZ1[epoch][1], traj_ZZ1.t) - 1
            SE = SquaredError(traj_ZZ1.x[1:t], y)
            push!(SE_list, SE)
        end
        SE_sum += SE_list
    end
    return SE_sum ./ N, mean(acc_list)
end

# ESS_Affine, var_ESS_Affine, ESS_Global, var_ESS_Global = experiment_ZZ(10, T, dt; ξ0=0.0, θ0=1.0, n_list=n_list)

using Plots

N=3

MSE_MALA = experiment_MALA(Vector{Int64}(epoch_list), N, y1)

using GLM, DataFrames

p = plot(#epoch_list, MSE_ZZ1,
    xscale=:log10,
    yscale=:log10,
    xlabel="epochs",
    ylabel="MSE"
    # ,background_color = "#F0F1EB"
    )
scatter!(p, epoch_list, MSE_MALA,
    marker=:circle,
    markersize=5,
    markeralpha=0.6,
    color="blue",
    label=nothing
    )

df = DataFrame(X = log10.(epoch_list), Y = log10.(MSE_MALA))
model = lm(@formula(Y ~ X), df)
X_pred = range(minimum(df.X), maximum(df.X), length=100)
Y_pred = predict(model, DataFrame(X = X_pred))
plot!(p, 10 .^ X_pred, 10 .^ Y_pred,
    line=:solid,
    linewidth=2,
    label="MALA"
    )

display(p)

# １回目の実行は 1h 16m 31s かかりました．
# ２回目の実行は 3h 17m 5s かかった．