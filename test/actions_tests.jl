using AdversarialDriving
using Test
using POMDPs

## Test PedestrianControl conversion functions
@test PEDESTRIAN_DISTURBANCE_DIM == 5

pc = PedestrianControl(a = (-0.1, 0.1), da = (0.2, 0.3), noise = Noise((0.5, 0.6), 0.7))
vec = PedestrianControl_to_vec(pc)
@test vec == [0.2, 0.3, 0.5, 0.6, 0.7]

pc2 = vec_to_PedestrianControl([0.2, 0.3, 0.5, 0.6, 0.7])
@test all(pc2.a .== (0, 0))
@test pc2.da == pc.da
@test pc2.noise == pc.noise

## Test BlinkerVehicleConstrol conversion functions
@test BLINKERVEHICLE_DISTURBANCE_DIM == 5

bv = BlinkerVehicleControl(a = 1., da=0.1, toggle_goal = true, toggle_blinker = false, noise = Noise((0.5, 0.6), 0.7))
v = BlinkerVehicleControl_to_vec(bv)
@test v == [0.1, 1., 0., 0.5, 0.7]

bv2 = vec_to_BlinkerVehicleControl([0.1, 0.5, -0.5, 0.5, 0.7])
@test bv2.a == 0
@test bv2.da == bv.da
@test bv2.toggle_goal == bv.toggle_goal
@test bv2.toggle_blinker == bv.toggle_blinker
@test bv2.noise.pos[1] ==  bv.noise.pos[1]
@test bv2.noise.vel ==  bv.noise.vel
@test bv2.noise.pos[2] == 0

## Test Convert_a functions

sut_agent = BlinkerVehicleAgent(get_ped_vehicle(id=1, s=5., v=15.), TIDM(ped_TIDM_template, noisy_observations = true))
adv_vehicle = BlinkerVehicleAgent(get_ped_vehicle(id=2, s=15., v=15.), TIDM(ped_TIDM_template), disturbance_model = Sampleable[])
adv_ped = NoisyPedestrianAgent(get_pedestrian(id=3, s=7., v=2.0), AdversarialPedestrian(), disturbance_model = Sampleable[])
mdp = AdversarialDrivingMDP(sut_agent, [adv_vehicle, adv_ped], ped_roadway, 0.1,)

a = [bv, pc]
avec = convert_a(AbstractArray, a, mdp)
@test avec[1:5] == v
@test avec[6:10] == vec
a2 = convert_a(Vector{Disturbance}, avec, mdp)
@test a2[1] == bv2
@test a2[2] == pc2

@test_throws ErrorException actions(mdp)

# Create two agents and construct their actions
bv1 = BlinkerVehicleAgent(left_straight(id=1), TIDM(Tint_TIDM_template))
bv2 = BlinkerVehicleAgent(right_straight(id=2), TIDM(Tint_TIDM_template))
advs = [bv1, bv2]
d = combine_discrete(advs)
@test d isa DiscreteActionModel

# Test action construction, probabilities and indexing
acts = d.actions
for (a, i) in zip(acts, 1:length(acts))
    @test get_actionindex(d, a) == i
end

BV_ACTIONS = bv1.disturbance_model.actions
@test length(acts) == 13
@test acts[1] == [BV_ACTIONS[1][1], BV_ACTIONS[1][1]]
@test acts[2] == [BV_ACTIONS[2][1], BV_ACTIONS[1][1]]
@test acts[7] == [BV_ACTIONS[7][1], BV_ACTIONS[1][1]]
@test acts[8] == [BV_ACTIONS[1][1], BV_ACTIONS[2][1]]
@test acts[13] == [BV_ACTIONS[1][1], BV_ACTIONS[7][1]]

action_prob = d.probs
BV_ACTION_PROB = bv1.disturbance_model.probs
@test isapprox(BV_ACTION_PROB[1], action_prob[1])
aprob2 = action_prob[2]
aprob3 = action_prob[3]
@test isapprox(aprob3/aprob2, 10.)


as = get_ped_actions()
as.actions
@test as.actions[2][1].da[1] == 1.
@test as.probs[2] == 1e-2

