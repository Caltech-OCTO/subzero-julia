
"""
    determine_fractures(
        floes,
        criteria,
        min_floe_area,
    )

Determines which floes will fracture depending on the principal stress criteria.
Inputs:
    floes           <StructArray{Floe}> model's list of floes
    criteria        <AbstractFractureCriteria> fracture criteria
    floe_settings   <FloeSettings> Floe settings. Contains Floe properties and stress 
                    calculator.
Outputs:
    <Vector{Int}> list of indices of floes to fracture 
"""
function determine_fractures(
    floes,
    criteria::AbstractFractureCriteria,
    floe_settings, 
)
    # Determine if floe stresses are in or out of criteria allowable regions
    _update_criteria!(criteria, floes)
    # If stresses are outside of criteria regions, we will fracture the floe
    frac_idx = [!GO.coveredby(find_σpoint(get_floe(floes, i), floe_settings), criteria.poly) for i in eachindex(floes)]
    frac_idx[floes.area .< floe_settings.min_floe_area] .= false
    return range(1, length(floes))[frac_idx]
end

# Find floe's accumulated stress in principal stress space so that is can be compared to the
# fracture criteria. 
function find_σpoint(floe::FloeType, floe_settings)
    σvals = eigvals(floe.stress_accum)
    _scale_principal_stress!(floe_settings.stress_calculator, σvals, floe, floe_settings)
    return σvals
end

"""
    deform_floe!(
        floe,
        deformer_poly,
        deforming_forces,
    )

Deform a floe around the area of its collision with largest area overlap within
the last timestep.
Inputs:
        floe                <Floe> floe to deform
        deformer_coords     <PolyVec> coords of floe that is deforming floe
                                argument
        deforming_forces    <Vector{AbstractFloat}> 1x2 matrix of forces between
                                floe and the deforming floe from floe's
                                interactions - of the form: [xforce yforce] 
Outputs:
        None. The input floe's centroid, coordinates, and area are updated to
        reflect a deformation due to the collision with the deforming floe. 
"""
function deform_floe!(
    floe,
    deformer_poly::Polys{FT},
    deforming_forces,
    floe_settings,
    Δt,
    rng,
) where FT
    poly = floe.poly
    overlap_regions = intersect_polys(poly, deformer_poly, FT)
    max_overlap_area, max_overlap_idx = findmax(GO.area, overlap_regions)
    overlap_region = overlap_regions[max_overlap_idx]
    # If floe and the deformer floe have an overlap area
    if max_overlap_area > 0
        # Determine displacement of deformer floe
        region_cent = GO.centroid(overlap_region)
        dist = GO.signed_distance(region_cent,overlap_region, FT)
        force_fracs = deforming_forces ./ 2norm(deforming_forces)
        Δx, Δy = abs.(dist)[1] .* force_fracs
        # Temporarily move deformer floe to find new shape of floe
        deformer_poly = _translate_poly(FT, deformer_poly, Δx, Δy)
        new_floes = diff_polys(poly, deformer_poly, FT)
        new_floe_area, new_floe_idx = findmax(GO.area, new_floes)
        new_floe_poly = new_floes[new_floe_idx]
        # If didn't change floe area by more than 90%
        if new_floe_area > 0 && new_floe_area/floe.area > 0.9
            # Update floe shape and conserve mass
            moment_tmp = floe.moment
            x_tmp, y_tmp = floe.centroid
            replace_floe!(
                floe,
                new_floe_poly,
                floe.mass,
                floe_settings,
                rng,
            )
            conserve_momentum_change_floe_shape!(
                floe.mass,
                moment_tmp,
                x_tmp,
                y_tmp,
                Δt,
                floe,
            )
        end
    end
    return
end

"""
    split_floe(
        floe,
        rng,
        fracture_settings,
        floe_settings,
        Δt,
    )
Splits a given floe into pieces using voronoi tesselation.
User will recieve a warning if floe isn't split.
Inputs:
    floe              <Floe> floe in simulation
    rng               <RNG> random number generator used for voronoi tesselation
    fracture_settings <FractureSettings> simulation's fracture settings
    floe_settings     <FloeSettings> simulation's settings for making floes
    Δt                <Int> length of simulation timesteps in seconds
Outputs:
    new_floes   <StructArray{Floes}> list of pieces floe is split into, each of
                    which is a new floe
"""
function split_floe(
    floe::Union{Floe{FT}, LazyRow{Floe{FT}}},
    rng,
    fracture_settings,
    floe_settings,
    Δt,
) where {FT}
    new_floes = StructArray{Floe{FT}}(undef, 0)
    # Generate voronoi tesselation in floe's bounding box
    scale_fac = fill(2floe.rmax, 2)
    trans_vec = [floe.centroid[1] - floe.rmax, floe.centroid[2] - floe.rmax]
    pieces = generate_voronoi_coords(
        fracture_settings.npieces,
        scale_fac,
        trans_vec,
        [floe.coords],
        rng,
        1,  # Warn if only 1 point is identified as the floe won't be split
    )
    if !isempty(pieces)
        # Intersect voronoi tesselation pieces with floe
        rmholes!(floe.poly)
        pieces_polys = mapreduce(p -> intersect_polys(make_polygon(p), floe.poly, FT), append!, pieces; init = Vector{Polys{FT}}())
        # Conserve mass within pieces
        pieces_areas = [GO.area(p) for p in pieces_polys]
        total_area = sum(pieces_areas)
        # Create floes out of each piece
        for i in eachindex(pieces_polys)
            if pieces_areas[i] > 0
                mass = floe.mass * (pieces_areas[i]/total_area)
                height = mass / (floe_settings.ρi * pieces_areas[i])
                poly_to_floes!(
                    FT,
                    new_floes,
                    pieces_polys[i],
                    height,
                    0, # Δh - range of random height difference between floes
                    floe.rmax;
                    floe_settings = floe_settings,
                    rng = rng,
                    u = floe.u,
                    v = floe.v,
                    ξ = floe.ξ,
                )
            end
        end
    end

    # Conserve momentum and update strain
    conserve_momentum_fracture_floe!(
        floe,
        new_floes,
        Δt,
    )
    for s in new_floes.strain
        s .= floe.strain
    end

    return new_floes
end

"""
    fracture_floes!(
        floes,
        max_floe_id,
        rng,
        fracture_settings,
        floe_settings,
        Δt,
    )
Fractures floes that meet the criteria defined in the fracture settings.
Inputs:
    floes       <StructArray{Floe}> model's list of floes
    max_floe_id <Int> maximum ID of any floe created so far in simulation
    rng         <RNG> random number generator
    fracture_settings   <FractureSettings> sim's fracture settings
    floe_settings       <FloeSettings> sim's settings to make floes
    Δtout               <Int> length of simulation timestep in seconds
Outputs:
    max_floe_id <Int> new highest floe ID after adding new floes to floe array.
    Floe pieces added to floe array and original fractured floes removed.
"""
function fracture_floes!(
    floes::StructArray{<:Floe{FT}},
    max_floe_id,
    rng,
    fracture_settings,
    floe_settings,
    Δt,
) where {FT <: AbstractFloat}
    # Determine which floes will fracture
    frac_idx = determine_fractures(
        floes,
        fracture_settings.criteria,
        floe_settings,
    )
    # Initialize list for new floes created from fracturing existing floes
    nfloes2frac = length(frac_idx)
    fracture_list = [StructArray{Floe{FT}}(undef, 0) for _ in 1:nfloes2frac]
    # Fracture floes that meet criteria 
    Threads.@threads for i in 1:nfloes2frac
        # Deform floe around largest impact site
        if fracture_settings.deform_on
            fidx = frac_idx[i]
            max_overlap = FT(0)
            max_overlap_idx = 0
            for i in 1:floes.num_inters[fidx]
                if (
                    floes.interactions[fidx][i, floeidx] > 0 &&
                    max_overlap < floes.interactions[fidx][i, overlap]
                )
                    max_overlap = floes.interactions[fidx][i, overlap]
                    max_overlap_idx = i
                end
            end
            if max_overlap > 0
                deforming_inter = floes.interactions[fidx][max_overlap_idx, :]
                deforming_floe_idx = Int(deforming_inter[floeidx])
                if deforming_floe_idx <= length(floes)
                    deform_floe!(
                        get_floe(floes, frac_idx[i]), 
                        floes.poly[deforming_floe_idx],
                        deforming_inter[xforce:yforce],
                        floe_settings,
                        Δt,
                        rng,
                    )
                end
            end
        end
        # Split flie into pieces
        new_floes = split_floe(
            get_floe(floes, frac_idx[i]),
            rng,
            fracture_settings,
            floe_settings,
            Δt,
        )
        append!(fracture_list[i], new_floes)
    end
    # Remove old (unfractured) floes and add fractured pieces
    for i in range(nfloes2frac, 1, step = -1)
        new_floes = fracture_list[i]
        if !isempty(new_floes)
            n_new_floes = length(new_floes)
            new_floes.id .= range(max_floe_id + 1, max_floe_id + n_new_floes)
            push!.(new_floes.parent_ids, floes.id[frac_idx[i]])
            append!(floes, new_floes)
            max_floe_id += n_new_floes
            StructArrays.foreachfield(f -> deleteat!(f, frac_idx[i]), floes)
        end
    end
    return max_floe_id
end

