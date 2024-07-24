using ZigZagBoomerang
using Distributions
using Random
using LinearAlgebra
using Statistics  # just for sure
using StatsFuns

"""
    ∇U(i,j,ξ,x,y)
        i ∈ [d]: 次元を表すインデックス
        j ∈ [n]: サンプル番号を表すインデックス
        ξ: パラメータ空間 R^d 上の位置
        他，観測 (x,y) を引数にとる．
    この関数を実装する際，log の中身をそのまま計算しようとすると大変大きくなり，数値的に不安定になる（除算の後は 1 近くになるはずだが，Inf になってしまう）
"""
∇U(i::Int64, j::Int64, ξ, x::Matrix{Float64}, y::Vector{Float64}) = length(y) * x[i,j] * (logistic(dot(x[:,j],ξ)) - y[j])

"""
    ∇U(i,ξ,x,y)：∇U(i,j,ξ,x,y) を全データ j ∈ [n] について足し合わせたもの
        i ∈ [d]: 次元を表すインデックス
        ξ: パラメータ空間 R^d 上の位置
        他，観測 (x,y) を引数にとる．
"""
function ∇U(i::Int64, ξ, x::Matrix{Float64}, y::Vector{Float64})
    n = length(y)
    U_list = []
    for j in 1:n
        push!(U_list, ∇U(i, j, ξ, x, y))
    end
    return mean(U_list)
end

function  ∇U(ξ, x::Matrix{Float64}, y::Vector{Float64})  # 1次元の場合のショートカット
    return ∇U(1, ξ, x, y)
end

pos(x) = max(zero(x), x)

"""
    λ(i, ξ, θ, ∇U, x, y)：第 i ∈ [d] 次元のレート関数
        i ∈ [d]: 次元を表すインデックス
        (ξ,θ): E 上の座標
        ∇U
        (x,y): 観測
"""
λ(i::Int64, ξ, θ, ∇U, x, y) = pos(θ[i] * ∇U(i, ξ, x, y))
λ(ξ, θ, ∇U, x, y) = pos(θ * ∇U(ξ, x, y))  # 1次元の場合のショートカット

"""
    λ(τ, a, b)：代理レート関数の時刻 τ における値
        τ: 時間
        a,b: 1次関数の係数
"""
λ_bar(τ, a, b) = pos(a + b*τ)

"""
`x`: current location, `θ`: current velocity, `t`: current time,
"""
function move_forward(τ, t, ξ, θ, ::ZigZag1d)
    τ + t, ξ + θ*τ , θ
end

"""
    ZZ1d(∇U, ξ, θ, T, x, y, Flow; rng=Random.GLOBAL_RNG, ab=ab_Global)：ZigZag sampler without subsampling
        `∇U`: gradient of the negative log-density
        `(ξ,θ)`: initial state
        `T`: Time Horizon
        `(x,y)`: observation
        `Flow`: continuous dynamics

        `a+bt`: computational bound for intensity m(t)

        `num`: ポアソン時刻に到着した回数
        `acc`: 受容回数．`acc/num` は acceptance rate
"""
function ZZ1d(∇U, ξ, θ, T::Float64, x::Matrix{Float64}, y::Vector{Float64}, Flow::ZigZagBoomerang.ContinuousDynamics; rng=Random.GLOBAL_RNG, ab=ab_Global)
    t = zero(T)
    Ξ = [(t, ξ, θ)]
    num = acc = 0
    epoch_list = [num]
    a, b = ab(ξ, θ, x, y, Flow)
    t′ =  t + poisson_time(a, b, rand())  # イベントは a,b が定める affine proxy に従って生成する

    while t < T
        τ = t′ - t
        t, ξ, θ = move_forward(τ, t, ξ, θ, Flow)
        l, lb = λ(ξ, θ, ∇U, x, y), λ_bar(τ, a, b)  # λ が真のレート, λ_bar が affine proxy
        num += 1
        if rand()*lb < l
            acc += 1
            if l > lb + 0.01
                println(l-lb)
                println(l)
            end
            θ = -θ
            push!(Ξ, (t, ξ, θ))
            push!(epoch_list, num)
        end
        a, b = ab(ξ, θ, x, y, Flow)
        t′ = t + poisson_time(a, b, rand())
    end

    return Ξ, epoch_list, acc/num
end

a_Global(ξ, θ, x, y) = length(y) * maximum(abs.(vec(x)))
b_Global(ξ, θ, x, y) = 0

ab_Global(ξ, θ, x, y, ::ZigZag1d) = (a_Global(ξ, θ, x, y), b_Global(ξ, θ, x, y))

"""
    U(ξ, x, y)：ポテンシャル関数
        ξ: パラメータ空間上の点
        (x,y): 観測
"""
function U(ξ, x, y)
    n = length(y)
    U_list = []
    for j in 1:n
        push!(U_list, U(j, ξ, x, y))
    end
    return mean(U_list)
end
function U(j, ξ, x, y)
    n = length(y)
    product = dot(x[:,j],ξ)
    return -n * log(exp(y[j] * product) / (1 + exp(product)))
end

using StatsFuns
using Distributions

ξ0 = [1] # True value
n_list = [10, 100, 1000]  # 実験で用いるサンプルサイズの列

# Σ = [2]
# x = rand(MvNormal(ξ0, Σ), n_list[end])
# y = rand.(Bernoulli.(logistic.(ξ0*x)))  # BitVector になってしまう
# y = Float64.(vec(y))  # Vector{Float64} に変換

using JLD2
@load "Logistic2_data.jld2" x y

using Optim

result = optimize(ξ -> U(ξ, x, y), [0.0], LBFGS())
ξ_star = Optim.minimizer(result)

function C(ξ, θ, x, y)
    n = length(y)
    max_value = maximum(x.^2)
    return n * max_value / 4
end

a_Affine(ξ, θ, x, y) = pos(θ * ∇U(ξ_star,x,y)) + C(ξ, θ, x, y) * abs(ξ - ξ_star[1])
b_Affine(ξ, θ, x, y) = C(ξ, θ, x, y)

# computational bounds for intensity m(t)
ab_Affine(ξ, θ, x, y, ::ZigZag1d) = (a_Affine(ξ, θ, x, y), b_Affine(ξ, θ, x, y))

function λj_Global(j::Int64, ξ, θ, ∇U, x, y)
    Eʲ = ∇U(1, j, ξ, x, y)
    return pos(θ * Eʲ)
end

function ZZ1d_SS(∇U, ξ, θ, T::Float64, x::Matrix{Float64}, y::Vector{Float64}, Flow::ZigZagBoomerang.ContinuousDynamics; rng=Random.GLOBAL_RNG, ab=ab_Global)
    t = zero(T)
    Ξ = [(t, ξ, θ)]
    num = acc = 0
    epoch_list = [num]
    a, b = ab(ξ, θ, x, y, Flow)
    t′ =  t + poisson_time(a, b, rand())  # イベントは a,b が定める affine proxy に従って生成する

    while t < T
        τ = t′ - t
        t, ξ, θ = move_forward(τ, t, ξ, θ, Flow)
        j = rand(1:length(y))
        l, lb = λj_Global(j, ξ, θ, ∇U, x, y), λ_bar(τ, a, b)  # λ が真のレート, λ_bar が affine proxy
        num += 1
        if rand()*lb < l
            acc += 1
            if l > lb + 0.01
                println(l-lb)
            end
            θ = -θ
            push!(Ξ, (t, ξ, θ))
            push!(epoch_list, num)
        end
        a, b = ab(ξ, θ, x, y, Flow)
        t′ = t + poisson_time(a, b, rand())
    end

    return Ξ, epoch_list, acc/num
end

function λj(j::Int64, ξ, θ, ∇U, x, y)
    Eʲ = ∇U(ξ_star, x, y) + ∇U(1, j, ξ, x, y) - ∇U(1, j, ξ_star, x, y)
    return pos(θ * Eʲ)
end

function ZZ1d_CV(∇U, ξ, θ, T::Float64, x::Matrix{Float64}, y::Vector{Float64}, Flow::ZigZagBoomerang.ContinuousDynamics; rng=Random.GLOBAL_RNG, ab=ab_Affine)
    t = zero(T)
    Ξ = [(t, ξ, θ)]
    num = acc = 0
    epoch_list = [num]
    a, b = ab(ξ, θ, x, y, Flow)
    t′ =  t + poisson_time(a, b, rand())  # イベントは a,b が定める affine proxy に従って生成する

    while t < T
        τ = t′ - t
        t, ξ, θ = move_forward(τ, t, ξ, θ, Flow)
        j = rand(1:length(y))
        l, lb = λj(j, ξ, θ, ∇U, x, y), λ_bar(τ, a, b)  # λ が真のレート, λ_bar が affine proxy
        num += 1
        if rand()*lb < l
            acc += 1
            if l > lb + 0.01
                println(l-lb)
            end
            θ = -θ
            push!(Ξ, (t, ξ, θ))
            push!(epoch_list, num)
        end
        a, b = ab(ξ, θ, x, y, Flow)
        t′ = t + poisson_time(a, b, rand())
    end

    return Ξ, epoch_list, acc/num
end

function ESS(samples::Vector{Float64}, T, dt)
    B = T / dt
    V = (dt / T) * sum(samples.^2) - ((dt / T) * sum(samples))^2
    Y = samples .* sqrt(T / B)
    ESS = T * V / var(Y)
    return ESS
end

function getESSperEpoch(ab, T ,dt, x, y; ξ0=0.0, θ0=1.0)
    trace, epochs, acc = ZZ1d(∇U, ξ0, θ0, T, x, y, ZigZag1d(); ab=ab)
    traj = discretize(trace, ZigZag1d(), dt)
    return ESS(traj.x, T, dt) / epochs[end]
end

N = 10
T = 500.0
dt = 0.1

function experiment_ZZ(N, T, dt; ξ0=0.0, θ0=1.0, n_list=[10, 100, 1000])  # サブサンプリングなしの ZZ() に関して N 回実験
    ESSs_sum_Affine = zero(n_list)
    ESSs_sum_Global = zero(n_list)

    for _ in 1:N
        ESSs_Affine = []
        ESSs_Global = []
        for n in n_list
            push!(ESSs_Affine, getESSperEpoch(ab_Affine, T, dt, x[:,1:n], y[1:n]; ξ0=ξ0, θ0=θ0))
            push!(ESSs_Global, getESSperEpoch(ab_Global, T, dt, x[:,1:n], y[1:n]; ξ0=ξ0, θ0=θ0))
        end
        ESSs_sum_Affine = [ESSs_sum_Affine ESSs_Affine]
        ESSs_sum_Global = [ESSs_sum_Global ESSs_Global]
    end
    return mean(ESSs_sum_Affine, dims=2), var(ESSs_sum_Affine, dims=2), mean(ESSs_sum_Global, dims=2), var(ESSs_sum_Global, dims=2)
end

function getESSperEpoch_SS(ab, ZZ, T ,dt, x, y; ξ0=0.0, θ0=1.0)
    trace, epochs, acc = ZZ(∇U, ξ0, θ0, T, x, y, ZigZag1d(); ab=ab)
    traj = discretize(trace, ZigZag1d(), dt)
    return ESS(traj.x, T, dt) * length(y) / epochs[end]  # サブサンプリングをしているので length(y) で補正する必要あり
end

N = 10
T = 500.0
dt = 0.1

function experiment_ZZ_SS(N, T, dt; ξ0=0.0, θ0=1.0, n_list=[10, 100, 1000])  # サブサンプリングなしの ZZ() に関して N 回実験
    ESSs_sum_CV = zero(n_list)
    ESSs_sum_SS = zero(n_list)

    for _ in 1:N
        ESSs_CV = []
        ESSs_SS = []
        for n in n_list
            push!(ESSs_CV, getESSperEpoch_SS(ab_Affine, ZZ1d_CV, T, dt, x[:,1:n], y[1:n]; ξ0=ξ0, θ0=θ0))
            push!(ESSs_SS, getESSperEpoch_SS(ab_Global, ZZ1d_SS, T, dt, x[:,1:n], y[1:n]; ξ0=ξ0, θ0=θ0))
        end
        ESSs_sum_CV = [ESSs_sum_CV ESSs_CV]
        ESSs_sum_SS = [ESSs_sum_SS ESSs_SS]
    end
    return mean(ESSs_sum_CV, dims=2), var(ESSs_sum_CV, dims=2), mean(ESSs_sum_SS, dims=2), var(ESSs_sum_SS, dims=2)
end

ESS_CV, var_ESS_CV, ESS_SS, var_ESS_SS = experiment_ZZ_SS(10, T, dt; ξ0=0.0, θ0=1.0, n_list=n_list)

using JLD2

@save "Logistic2_Experiment2.jld2" ESS_CV var_ESS_CV ESS_SS var_ESS_SS

## 第一回実行：13m 12s
## 第二回実行：8m 13s