using Plots

using DynamicalSystems

function lorenz96_rule!(du, u, p, t)
    F = p[1]; N = length(u)
    # 3 edge cases
    du[1] = (u[2] - u[N - 1]) * u[N] - u[1] + F
    du[2] = (u[3] - u[N]) * u[1] - u[2] + F
    du[N] = (u[1] - u[N - 2]) * u[N - 1] - u[N] + F
    # then the general case
    for n in 3:(N - 1)
        du[n] = (u[n + 1] - u[n - 2]) * u[n - 1] - u[n] + F
    end
    return nothing # always `return nothing` for in-place form!
end

N = 6
u0 = range(0.1, 1; length = N)
p0 = [8.0]
lorenz96 = CoupledODEs(lorenz96_rule!, u0, p0)

total_time = 12.5
sampling_time = 0.02
Y, t = trajectory(lorenz96, total_time; Ttr = 2.2, Δt = sampling_time)



# アニメーションの作成
anim = @animate for i in 1:5:626
    plot(Y[1:i, 1], Y[1:i, 2], Y[1:i, 3],
        zcolor=t[1:i],
        w=3,
        m=(3, :circle, :plasma, Plots.stroke(0)),
        alpha=0.6,
        legend=false,
        title="Lorenz 96 Model",
        xlabel="X₁", ylabel="X₂", zlabel="X₃",
        camera=(30, 30),
        colorbar=false,
        size=(800, 600),
        xlims=(-5, 10),
        ylims=(-5, 10),
        zlims=(-5, 10)
    )
end

# GIFとして保存
gif(anim, "lorenz96_animation.gif", fps = 14)

# 最終フレームの静止画を表示
# plot(Y[1:500, 1], Y[1:500, 2], Y[1:500, 3],
#     zcolor=t[1:500],
#     m=(1, :circle, :viridis, Plots.stroke(0)),
#     alpha=0.6,
#     legend=false,
#     title="Lorenz 96 Model",
#     xlabel="X₁", ylabel="X₂", zlabel="X₃",
#     camera=(30, 30),
#     colorbar=true,
#     colorbar_title="Time",
#     size=(800, 600)
# )