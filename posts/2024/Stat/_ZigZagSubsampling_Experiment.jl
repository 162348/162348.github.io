using ZigZagBoomerang
using Distributions
using Random

λ(∇U, x, θ, F::ZigZag1d) = pos(θ*∇U(x)) # rate function on E
λ_bar(τ, a, b) = pos(a + b*τ)  # affine proxy

"""
`x`: current location, `θ`: current velocity, `t`: current time,
"""
function move_forward(τ, t, x, θ, ::ZigZag1d)
    τ + t, x + θ*τ , θ
end

"""
    `∇U`: gradient of the negative log-density
    `(x,θ)`: initial state
    `T`: Time Horizon    
    `a+bt`: computational bound for intensity m(t)

    `num`: ポアソン時刻に到着した回数
    `acc`: 受容回数．`acc/num` は acceptance rate
"""
function ZZ(∇U, x::Float64, θ::Float64, T::Float64, y, Flow::ZigZagBoomerang.ContinuousDynamics; rng=Random.GLOBAL_RNG, ab=ab_ZZ)
    t = zero(T)
    Ξ = [(t, x, θ)]
    num = acc = 0
    epoch_list = [num]
    a, b = ab(x, θ, Flow)
    t′ =  t + poisson_time(a, b, rand())  # イベントは a,b が定める affine proxy に従って生成する

    while t < T
        τ = t′ - t
        t, x, θ = move_forward(τ, t, x, θ, Flow)
        l, lb = λ(∇U, x, θ, Flow), λ_bar(τ, a, b)  # λ が真のレート, λ_bar が affine proxy
        num += 1
        if rand()*lb < l
            acc += 1
            if l > lb + 0.01
                println(l-lb)
            end
            θ = -θ
            push!(Ξ, (t, x, θ))
            push!(epoch_list, num)
        end
        a, b = ab(x, θ, Flow)
        t′ = t + poisson_time(a, b, rand())
    end

    return Ξ, epoch_list, acc/num
end

pos(x) = max(zero(x), x)  # positive part
a(x, θ, ρ, σ, y) = θ * x / ρ^2 + (θ/σ^2) * sum(x .- y)
b(x, θ, ρ, σ, y) = ρ^(-2) + length(y)/σ^2

ρ, σ, x0, θ0 = 1.0, 1.0, 1.0, 1.0
n1, n2 = 100, 10^4
TrueDistribution = Normal(x0, σ)
y1 = rand(TrueDistribution, n1)
y2 = rand(TrueDistribution, n2)

# computational bounds for intensity m(t)
ab_ZZ_n1(x, θ, ::ZigZag1d) = (a(x, θ, ρ, σ, y1), b(x, θ, ρ, σ, y1))
ab_ZZ_n2(x, θ, ::ZigZag1d) = (a(x, θ, ρ, σ, y2), b(x, θ, ρ, σ, y2))

∇U1(x) = x/ρ^2 + (length(y1)/σ^2) * (x - mean(y1)) 
∇U2(x) = x/ρ^2 + (length(y2)/σ^2) * (x - mean(y2)) 

function SquaredError(sample::Vector{Float64}, y)
    True_Posterior_Mean = sum(y) / (length(y) + 1)  # 1.12
    return (mean(sample) - True_Posterior_Mean)^2
end