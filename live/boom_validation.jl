#!/usr/bin/env julia
# boom_validation.jl — validate-before-live gate for BOOM (mega-cap momentum tilt).
include(joinpath(@__DIR__, "boom_live.jl"))
include(joinpath(@__DIR__, "_sleeve_validation.jl"))
boom_net(panel, cap) = (w = boom_weights(panel.returns)[1]; (; net = Dict(panel.symbols[j] => w[j] for j in eachindex(w))))
validate_sleeve(boom_net; label = "BOOM", universe = UNIVERSE, warmup = 320, reb = 21, kind = :directional)
