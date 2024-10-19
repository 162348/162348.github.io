using ZigZagBoomerang
using SparseArrays

d = 2

# 対数尤度関数 ϕ の第 i 成分に関する微分を計算
Γ = sparse([1,1,2,2], [1,2,1,2], [2.0,-1.0,-1.0,2.0])
∇ϕ(x, i, Γ) = ZigZagBoomerang.idot(Γ, i, x)

# 初期値
t0 = 0.0
x0 = randn(d)
θ0 = rand([-1.0,1.0], d)

# Rejection bounds
c = 1.0 * ones(length(x0))

# ZigZag 過程をインスタンス化
Z = ZigZag(Γ, x0*0)

# シミュレーション実行
T = 2000.0
zigzag_trace, (tT, xT, θT), (acc, num) = spdmp(∇ϕ, t0, x0, θ0, T, c, Z, Γ; adapt=true)

# 軌跡を離散化
traj = collect(zigzag_trace)

# discretized = collect(discretize(zigzag_trace, 0.1))

# x_coords = [state[1] for (t, state) in discretized]
# y_coords = [state[2] for (t, state) in discretized]

# x_event_coords = [state[1] for (t, state) in traj]
# y_event_coords = [state[2] for (t, state) in traj]

traj_for_animation_x = []
traj_for_animation_y = []
event_time = []

dt = 0.1

for (point, n) in zip(traj,1:length(traj))
    if n == 1
        push!(traj_for_animation_x, point.second[1])
        push!(traj_for_animation_y, point.second[2])
        push!(event_time, length(traj_for_animation_x))
    elseif n != length(traj)
        displacement = traj[n+1].second - point.second
        distance = sqrt((point.second[1] - traj[n+1].second[1])^2 + (point.second[2] - traj[n+1].second[2])^2)
        step_number = round(Int, distance/dt)
        if step_number > 0
            step = displacement ./ step_number
            for i in 1:step_number
                push!(traj_for_animation_x, point.second[1] + step[1]*i)
                push!(traj_for_animation_y, point.second[2] + step[2]*i)
            end
            push!(event_time, length(traj_for_animation_x))
        else
            push!(traj_for_animation_x, traj[n+1].second[1])
            push!(traj_for_animation_y, traj[n+1].second[2])
            push!(event_time, length(traj_for_animation_x))
        end
    end
end

using Plots

p = plot(traj_for_animation_x[1:1], traj_for_animation_y[1:1], 
            xticks=false,
            yticks=false,
            xlims=(-3.2,3.2),
            ylims=(-3.2,3.2),
            label=false,
            title="Zig-Zag",
            linewidth=2,
            # marker=:circle,
            # markersize=2,
            # markeralpha=0.6,
            color="#78C2AD"
            #,background_color = "#F0F1EB"
)

using ProgressBars

anim = @animate for i in ProgressBar(1:min(length(traj_for_animation_x), 2000))
    push!(p, traj_for_animation_x[i], traj_for_animation_y[i])
    if i in event_time
        scatter!(p, traj_for_animation_x[i:i], traj_for_animation_y[i:i], marker=:circle, markersize=3, markeralpha=0.6, color="#E95420", label=false)
    end
end

gif(anim, "zigzag_fps14_WhiteBackground.gif", fps=14)