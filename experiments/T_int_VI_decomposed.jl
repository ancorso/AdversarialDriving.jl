include("plot_utils.jl")
include("../simulator/adm_task_generator.jl")
using POMDPs
using GridInterpolations
using LocalFunctionApproximation
using LocalApproximationValueIteration
using Serialization
using LinearAlgebra
using Distributions

decomposed, combined = generate_decomposed_scene(dt = 0.18)
policies = Array{Any}(undef, length(decomposed))
N = 27
pomdp = decomposed[4]
veh = get_by_id(pomdp.initial_scene, 1)
posf(veh.state).s
vel(veh.state)

for i in 1:length(decomposed)
    println("Solving decomposition ", i)
    pomdp = decomposed[i]
    veh = get_by_id(pomdp.initial_scene, 1)

    grid = RectangleGrid(
    # Vehicle 1
        range(posf(veh.state).s, stop=75,length=N), # position
        range(0, stop=29., length=N), # Velocity
        goals[laneid(veh)], # Goal
        [0.0, 1.0], # Blinker
    # Vehicle 2
        range(25, stop=75, length=N), # position
        range(0., stop=25., length=N), # Velocity
        [5.0], # Goal
        [1.0], # Blinker
        )

    interp = LocalGIFunctionApproximator(grid)  # Create the local function approximator using the grid

    solver = LocalApproximationValueIterationSolver(interp, is_mdp_generative = true, n_generative_samples = 1, verbose = true, max_iterations = 20)

    policy = solve(solver, pomdp)
    serialize(string("policy_decomp_", i, ".jls"), policy)
    policies[i] = policy
end

serialize("combined_policies.jls", policies)

# Not explicitly stored in policy - extract from value function interpolation
function stoch_action(policy::LocalApproximationValueIterationPolicy, s::S) where S
    mdp = policy.mdp
    sub_aspace = actions(mdp, s)

    probs = [value(policy, s, a) for a in actions(mdp,s)]
    probs = exp.(probs) ./ sum(exp.(probs))

    index = rand(Categorical(probs))

    return policy.action_map[index]
end

function joint_policy(policies, state::BlinkerScene)
    egoid = pomdp.egoid
    as = [index_to_action(stoch_action(policies[i], decompose_scene(state, [i, egoid]))) for i=1:length(policies)]
    push!(as, LaneFollowingAccelBlinker(0,0,false,false))
end

# do a rollout on the combined situation
o,a,r,scenes = policy_rollout(combined, (o) -> joint_policy(policies, convert_s(BlinkerScene,o, combined)), combined.initial_scene, save_scenes = true)

make_interact(scenes, combined.models, combined.roadway; egoid=combined.egoid)
make_video(scenes, combined.models, combined.roadway, "combined_rand.gif"; egoid = combined.egoid)


# Rollout the individual policies
for i=1:length(policies)
    o,a,r,scenes = policy_rollout(decomposed[i], (o) -> action(policies[i], convert_s(BlinkerScene, o, decomposed[i])), decomposed[i].initial_scene, save_scenes = true)

    make_video(scenes, decomposed[i].models, decomposed[i].roadway, string("decomposed_", i, ".gif"); egoid = decomposed[i].egoid)
end