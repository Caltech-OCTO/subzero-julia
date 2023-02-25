using Subzero, LibGEOS, JLD2, NCDatasets, StructArrays, SplitApplyCombine, Statistics, VoronoiCells, GeometryBasics, Random, PolygonInbounds
using Test

@testset "Subzero.jl" begin
    include("test_physical_processes/test_collisions.jl")
    include("test_physical_processes/test_coupling.jl")
    include("test_physical_processes/test_process_info.jl")
    include("test_physical_processes/test_fractures.jl")
    include("test_floe.jl")
    include("test_floe_utils.jl")
    include("test_model.jl")
    include("test_output.jl")
    include("test_simulation.jl")
end
