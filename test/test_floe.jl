@testset "Floe" begin
    # test generating monte carlo points
    file = jldopen("inputs/floe_shapes.jld2", "r")
    floe_coords = file["floe_vertices"][1:end]
    close(file)
    poly1 = LG.Polygon(Subzero.valid_polyvec!(floe_coords[1]))
    centroid1 = LG.GeoInterface.coordinates(LG.centroid(poly1))
    origin_coords = Subzero.translate(floe_coords[1], -centroid1)
    xo, yo = Subzero.separate_xy(origin_coords)
    rmax = sqrt(maximum([sum(xo[i]^2 + yo[i]^2) for i in eachindex(xo)]))
    area = LG.area(poly1)
    mc_x, mc_y, alive = Subzero.generate_mc_points(
        1000,
        origin_coords,
        rmax,
        area,
        true,
        Xoshiro(1)
    )
    @test length(mc_x) == length(mc_y) && length(mc_x) > 0
    in_on = inpoly2(hcat(mc_x, mc_y), hcat(xo, yo))
    mc_in = in_on[:, 1] .|  in_on[:, 2]
    @test all(mc_in)
    @test abs(sum(mc_in)/1000 * 4 * rmax^2 - area)/area < 0.1
    @test alive
    # Test that random number generator is working
    mc_x2, mc_y2, alive2 = Subzero.generate_mc_points(
        1000,
        origin_coords,
        rmax,
        area,
        true,
        Xoshiro(1)
    )
    @test all(mc_x .== mc_x2)
    @test all(mc_y .== mc_y2)
    @test alive == alive2

    # Test InteractionFields enum
    interactions = range(1, 7)'
    @test interactions[floeidx] == 1
    @test interactions[xpoint] == 4
    @test interactions[overlap] == 7

    # Test with coords inputs
    floe_from_coords = Floe(floe_coords[1], 0.5, 0.01, u = 0.2, rng = Xoshiro(1))
    @test typeof(floe_from_coords) <: Floe
    @test floe_from_coords.u == 0.2
    @test 0.49 <= floe_from_coords.height <= 0.51
    @test floe_from_coords.centroid == centroid1
    @test floe_from_coords.area == area
    @test floe_from_coords.alive
    
    # Test with polygon input
    floe_from_poly = Floe(poly1, 0.5, 0.01, v = -0.2, rng = Xoshiro(1))
    @test typeof(floe_from_poly) <: Floe
    @test floe_from_poly.u == 0.0
    @test floe_from_poly.v == -0.2
    @test 0.49 <= floe_from_poly.height <= 0.51
    @test floe_from_poly.centroid == centroid1
    @test floe_from_poly.area == area
    @test floe_from_poly.alive

    # Test poly_to_floes
    rect_poly = [[[0.0, 0.0], [0.0, 5.0], [10.0, 5.0], [10.0, 0.0], [0.0, 0.0]]]

    c_poly_hole = [[[0.0, 0.0], [0.0, 10.0], [10.0, 10.0], [10.0, 0.0],
        [4.0, 0.0], [4.0, 6.0], [2.0, 6.0], [2.0, 0.0], [0.0, 0.0]],
        [[6.0, 4.0], [6.0, 6.0], [7.0, 6.0], [7.0, 4.0], [6.0, 4.0]]]

    # Test polygon with no holes
    floe_arr = Subzero.poly_to_floes(LG.Polygon(rect_poly), 0.25, 0.01)
    @test length(floe_arr) == 1
    @test typeof(floe_arr[1]) <: Floe
    @test !Subzero.hashole(floe_arr.coords[1])

    # Test with polygon below minimum floe area
    floe_arr = Subzero.poly_to_floes(
        LG.Polygon(rect_poly),
        0.25,
        0.01,
        min_floe_area = 55
    )
    @test isempty(floe_arr)

    # Test with polygon with a hole that is split into 3 polyons
    floe_arr = Subzero.poly_to_floes(LG.Polygon(c_poly_hole), 0.25, 0.01)
    @test length(floe_arr) == 3
    @test !any(Subzero.hashole.(floe_arr.coords))
    @test typeof(floe_arr) <: StructArray{<:Floe}

    # Test with multipolygon 
    floe_arr = Subzero.poly_to_floes(
        LG.MultiPolygon([c_poly_hole, rect_poly]),
        0.25,
        0.01
    )
    @test length(floe_arr) == 4
    @test typeof(floe_arr) <: StructArray{<:Floe}

    # Test with multipolygon with minimum area
    floe_arr = Subzero.poly_to_floes(
        LG.MultiPolygon([c_poly_hole, rect_poly]),
        0.25,
        0.01,
        min_floe_area = 30
    )
    @test length(floe_arr) == 2
    @test typeof(floe_arr) <: StructArray{<:Floe}

    # Test initialize_floe_field from coord list
    grid = RegRectilinearGrid(
        Float64,
        (-8e4, 8e4),
        (-8e4, 8e4),
        1e4,
        1e4,
    )
    nbound = CollisionBoundary(grid, North())
    sbound = CollisionBoundary(grid, South())
    ebound = CollisionBoundary(grid, East())
    wbound = CollisionBoundary(grid, West())
    domain_no_topo = Domain(nbound, sbound, ebound, wbound)
    island = [[[6e4, 4e4], [6e4, 4.5e4], [6.5e4, 4.5e4], [6.5e4, 4e4], [6e4, 4e4]]]
    topo1 = [[[-8e4, -8e4], [-8e4, 8e4], [-6e4, 8e4], [-5e4, 4e4], [-6e4, -8e4], [-8e4, -8e4]]]
    domain_with_topo = Domain(
        nbound,
        sbound,
        ebound,
        wbound,
        StructVector([TopographyElement(t) for t in [island, topo1]])
    )
    topo_polys = LG.MultiPolygon([island, topo1])

    # From file without topography -> floes below recommended area
    floe_arr = (@test_logs (:warn, "Some user input floe areas are less than the suggested minimum floe area.") initialize_floe_field(floe_coords, domain_no_topo, 0.5, 0.1))
    nfloes = length(floe_coords)
    @test typeof(floe_arr) <: StructArray{<:Floe}
    @test length(floe_arr) == nfloes
    @test all(floe_arr.id .== range(1, nfloes))

    # From file with small domain -> floes outside of domain
    small_grid = RegRectilinearGrid(
        Float64,
        (-5e4, 5e4),
        (-5e4, 5e4),
        1e4,
        1e4,
    )
    small_domain_no_topo = Domain(
        CollisionBoundary(small_grid, North()),
        CollisionBoundary(small_grid, South()),
        CollisionBoundary(small_grid, East()),
        CollisionBoundary(small_grid, West())
    )
    floe_arr = (@test_logs (:warn, "Some floe centroids are out of the domain.") initialize_floe_field(floe_coords, small_domain_no_topo, 0.5, 0.1, min_floe_area = 1e5))
    @test typeof(floe_arr) <: StructArray{<:Floe}
    @test all(floe_arr.area .> 1e5)

    # From file with topography -> no intersection between topo and floes
    floe_arr = initialize_floe_field(
        floe_coords,
        domain_with_topo,
        0.5,
        0.1,
        min_floe_area = 10,
        rng = Xoshiro(0)
    )
    @test typeof(floe_arr) <: StructArray{<:Floe}
    @test all([LG.area(
        LG.intersection(LG.Polygon(c), topo_polys)
    ) for c in floe_arr.coords] .< 1e-6)

    # Test generate_voronoi_coords - general case
    domain_coords = [[[[1, 2], [1.5, 3.5], [1, 5], [2.5, 5], [2.5, 2], [1, 2]]]]
    bounding_box = [[[1, 2], [1, 5], [2.5, 5], [2.5, 2], [1, 2]]]
    voronoi_coords = Subzero.generate_voronoi_coords(
        10,
        [1.5, 3],
        [1, 2],
        domain_coords,
        Xoshiro(1),
        10,
        max_tries = 20 # 20 tries makes it very likely to reach 10 polygons
    )
    bounding_poly = LG.Polygon(bounding_box)
    @test length(voronoi_coords) == 10
    for c in voronoi_coords
        fpoly = LG.Polygon(c)
        @test isapprox(
            LG.area(LG.intersection(fpoly, bounding_poly)),
            LG.area(fpoly),
            atol = 1e-3,
        )
        @test LG.isValid(fpoly)
    end

    # Test warning and no points generated
    warning_str = "Only 0 floes were able to be generated in 10 tries during \
        voronoi tesselation."
    @test @test_logs (:warn, warning_str) Subzero.generate_voronoi_coords(
        0, # Don't generate any points
        [1.5, 3],
        [1, 2],
        domain_coords,
        Xoshiro(1),
        10, # Higher min to warn so we can test warning
    ) == Vector{Vector{Vector{Float64}}}()
    
    # Test initialize_floe_field with voronoi
    floe_arr = initialize_floe_field(
        25,
        [0.5],
        domain_with_topo,
        0.5,
        0.1,
        min_floe_area = 1e4,
        rng = Xoshiro(1)
    )
    @test isapprox(
        sum(floe_arr.area)/(1.6e5*1.6e5 - LG.area(topo_polys)),
        0.5,
        atol = 1e-1
    )
    @test all(floe_arr.area .> 1e4)
    @test all([LG.area(
        LG.intersection(LG.Polygon(c), topo_polys)
    ) for c in floe_arr.coords] .< 1e-6)
    nfloes = length(floe_arr)
    @test all(floe_arr.id .== range(1, nfloes))

    concentrations = [1 0.3; 0 0.5]
    rng = Xoshiro(2)
    floe_arr = initialize_floe_field(
        25,
        concentrations,
        domain_with_topo,
        0.5,
        0.1,
        min_floe_area = 1e4,
        rng = rng
    )
    nfloes = length(floe_arr)
    floe_polys = [LG.Polygon(f) for f in floe_arr.coords]
    first_cell = [[[-8e4, -8e4], [-8e4, 0], [0, 0], [0, -8e4], [-8e4, -8e4]]]
    for j in 1:2
        for i in 1:2
            cell = LG.Polygon(
                Subzero.translate(first_cell, [8e4*(j-1), 8e4*(i-1)])
            )
            open_cell_area = LG.area(LG.difference(cell, topo_polys))
            c = concentrations[i, j]
            floes_in_cell = [LG.intersection(p, cell) for p in floe_polys]
            @test c - 1e-3 <= sum(LG.area.(floes_in_cell))/open_cell_area < c + 2e-1
        end
    end
    @test all([LG.area(
        LG.intersection(p, topo_polys)
    ) for p in floe_polys] .< 1e-3)
    @test all([LG.isValid(p) for p in floe_polys])
    @test all(floe_arr.id .== range(1, nfloes))

    @testset "Stress/Strain" begin
        # Test Stress History buffer
        scb = Subzero.StressCircularBuffer{Float64}(10)
        @test scb.cb.capacity == 10
        @test scb.cb.length == 0
        @test eltype(scb.cb) <: Matrix{Float64}
        @test scb.total isa Matrix{Float64}
        @test all(scb.total .== 0)
        fill!(scb, ones(Float64, 2, 2))
        @test scb.cb.length == 10
        @test all(scb.total .== 10)
        @test scb.cb[1] == scb.cb[end] == ones(Float64, 2, 2)
        @test mean(scb) == ones(Float64, 2, 2)
        push!(scb, zeros(Float64, 2, 2))
        @test scb.cb.length == 10
        @test all(scb.total .== 9)
        @test scb.cb[end] == zeros(Float64, 2, 2)
        @test scb.cb[1] == ones(Float64, 2, 2)
        @test all(mean(scb) .== 0.9)

        # Test Stress and Strain Calculations
        floes = load(
            "inputs/test_floes.jld2",
            "stress_strain_floe1",
            "stress_strain_floe2",
        )
        stresses = [[-10.065, 36.171, 36.171, -117.458],
            [7.905, 21.913, 21.913, -422.242]]
        stress_histories = [[-4971.252, 17483.052, 17483.052, -57097.458],
            [4028.520, 9502.886, 9502.886, -205199.791]]
        strains = [[-3.724, 0, 0, 0], [7.419, 0, 0,	-6.987]]
        strain_multiplier = [1e28, 1e6]

        for i in eachindex(floes)
            f = floes[i]
            stress = Subzero.calc_stress!(f)
            @test all(isapprox.(vec(f.stress), stresses[i], atol = 1e-3))
            @test all(isapprox.(
                vec(f.stress_history.cb[end]),
                stress_histories[i],
                atol = 1e-3
            ))
            Subzero.calc_strain!(f)
            @test all(isapprox.(
                vec(f.strain) .* strain_multiplier[i],
                strains[i],
                atol = 1e-3
            ))
        end
    end
end