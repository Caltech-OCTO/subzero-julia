"""
Functions needed for collisions between floes, boundaries, and topography
"""

"""
    calc_normal_force(
        c1,
        c2,
        region,
        area,
        ipoints,
        force_factor,
    )

Calculate normal force for collision between polygons with coordinates c1 and c2
given an overlapping region, the area of that region, their intersection points
in the region, and a force factor. 
Inputs:
    c1           <PolyVec{Float64}> first polygon coordinates
    c2           <PolyVec{Float64}> second polygon coordinates
    region       <PolyVec{Float64}> coordiantes for one region of intersection
                    between the polygons
    area         <Float> area of region
    ipoints      <Vector{Tuple{Float, Float} or Vector{Vector{Float}}}> Points
                    of intersection between polygon 1 and 2
    force_factor <Float> Spring constant equivalent for collisions
Outputs:
        <Float> normal force of collision
        Δl <Float> mean length of distance between intersection points
"""
function calc_normal_force(
    c1,
    c2,
    region,
    area,
    ipoints,
    force_factor::FT,
) where {FT<:AbstractFloat}
    force_dir = zeros(FT, 2)
    coords = find_poly_coords(region)
    # Identify which region coordinates are the intersection points (ipoints)
    p = which_vertices_match_points(ipoints, coords)
    m = length(p)
    # Calculate force direction
    Δl = FT(0)
    if m == 2  # Two intersection points
        idx1, idx2 = p
        Δx = FT(coords[1][idx2][1] - coords[1][idx1][1])
        Δy = FT(coords[1][idx2][2] - coords[1][idx1][2])
        Δl = sqrt(Δx^2 + Δy^2)
        if Δl > 0.1  # If overlap is large enough to consider
            force_dir .= [-Δy/Δl; Δx/Δl]
        end
    elseif m != 0  # Unusual number of intersection points
        Δl = _many_intersect_normal_force!(FT, force_dir, region, make_polygon(c1), force_factor)
    end
    # Check if direction of the force desceases overlap, else negate direction
    if Δl > 0.1
        c1new = translate(c1, force_dir[1], force_dir[2])
        # Floe/boudary intersection after being moved in force direction
        new_regions_list = intersect_polys(make_polygon(c1new), make_polygon(c2))
        # See if the area of overlap has increased in corresponding region
        for new_region in new_regions_list
            if GO.intersects(new_region, region) && GO.area(new_region)/area > 1
                force_dir .*= -1 
            end
        end
    end
    return force_dir * area * force_factor, Δl
end

#=
    _many_intersect_normal_force!(::Type{T}, force_dir, region, poly, force_factor)
    
Calculate the force direction (`force_dir`) given more than two points of intersection
within the region between two polygons (the first of which is `poly`).
=#
function _many_intersect_normal_force!(::Type{T}, force_dir, region, poly, force_factor) where T
    x1, y1 = zero(T), zero(T)
    Δl, n_pts = zero(T), 0
    Fn_tot = (zero(T), zero(T))
    # Loop over each edge within the overlap region
    for (i, p) in enumerate(GI.getpoint(GI.getexterior(region)))
        x2, y2 = T(GI.x(p)), T(GI.y(p))
        if i == 1
            x1, y1 = x2, y2
            continue
        end
        # Find the edge midpoint and calculate distance to first polygon
        xmid, ymid = 0.5 * (x2 + x1), 0.5 * (y2 + y1)
        dist = abs(GO.signed_distance((xmid, ymid), poly, T))
        if dist < 1e-8  # Only consider region edge points on first polygon
            Δx, Δy = x2 - x1, y2 - y1
            mag = sqrt(Δx^2 + Δy^2)
            #= If force would push edge points closer to second polygon (past and out of the
            overlap region), switch the force direction =#
            xt = xmid + (-Δy / 100mag)
            yt = ymid + (Δx / 100mag)
            in_region = GO.coveredby((xt, yt), region) 
            f_sign = in_region ? 1 : -1
            # Calculate force from given edge and incorporate it into the total forces
            Fn = (f_sign * force_factor) .* (-Δy, Δx)
            Δl += mag
            n_pts += 1
            Fn_tot = Fn_tot .+ Fn
        end
        x1, y1 = x2, y2
    end
    # Take the average of the summed values
    if 0 < n_pts < (GI.npoint(region) - 1)
        Δl /= n_pts
        if Δl > 0.1  # If overlap is large enough to consider, set new force direction
            norm_Fn = sqrt(GI.x(Fn_tot)^2 + GI.y(Fn_tot)^2)
            force_dir[1] = GI.x(Fn_tot) / norm_Fn
            force_dir[2] = GI.y(Fn_tot) / norm_Fn
        end
    end
    return Δl
end

"""
    calc_elastic_forces(
        floe1,
        floe2,
        regions,
        region_areas,
        force_factor,
        consts,
    )

Calculate normal forces, the point the force is applied, and the overlap area of
regions created from floe collisions 
Inputs:
    c1              <PolyVec> first floe's coordinates in collision
    c2              <PolyVec> second floe's coordinates in collision
    regions         <Vector{Polygon}> polygon regions of overlap during
                        collision
    region_areas    <Vector{Float}> area of each polygon in regions
    force_factor    <Float> Spring constant equivalent for collisions
Outputs:
    force   <Array{Float, n, 2}> normal forces on each of the n regions greater
                than a minimum area
    fpoint  <Array{Float, n, 2}> point force is applied on each of the n regions
                greater than a minimum area
    overlap <Array{Float, n, 2}> area of each of the n regions greater than a
                minimum area
    Δl      <Float> mean length of distance between intersection points
"""
function calc_elastic_forces(
    c1,
    c2,
    regions,
    region_areas,
    force_factor::FT,
) where {FT<:AbstractFloat}
    ipoints = intersect_lines(c1, c2)  # Intersection points
    ncontact = 0
    if !isempty(ipoints) && length(ipoints) >= 2
        # Find overlapping regions greater than minumum area
        n1 = length(c1[1]) - 1
        n2 = length(c2[1]) - 1
        min_area = min(n1, n2) * 100 / 1.75
        for i in reverse(eachindex(region_areas))
            if region_areas[i] < min_area
                deleteat!(region_areas, i)
                deleteat!(regions, i)
            else
                ncontact += 1
            end
        end
    end
    # Calculate forces for each remaining region
    force = zeros(FT, ncontact, 2)
    fpoint = zeros(FT, ncontact, 2)
    overlap = ncontact > 0 ? region_areas : zeros(FT, ncontact)
    Δl_lst = zeros(FT, ncontact)
    for k in 1:ncontact
        if region_areas[k] != 0
            cx, cy = GO.centroid(regions[k])
            fpoint[k, 1] = cx
            fpoint[k, 2] = cy
            normal_force, Δl = calc_normal_force(
                c1,
                c2,
                regions[k],
                region_areas[k],
                ipoints,
                force_factor
            )
            force[k, 1] = normal_force[1]
            force[k, 2] = normal_force[2]
            Δl_lst[k] = Δl
        end
    end
    return force, fpoint, overlap, Δl_lst
end

"""
    get_velocity(
        floe,
        x,
        y,
    )

Get velocity of a point, assumed to be on given floe.
Inputs:
    floe <Union{LazyRow{Floe}, Floe}> floe
    x    <AbstractFloat> x-coordinate of point to find velocity at
    y    <AbstractFloat> y-coordinate of point to find velocity at
Outputs:
    u   <AbstractFloat> u velocity at point (x, y) assuming it is on given floe
    v   <AbstractFloat> v velocity at point (x, y) assuming it is on given floe
"""
function get_velocity(
    floe::Union{LazyRow{Floe{FT}}, Floe{FT}},
    x::FT,
    y::FT,
) where {FT}
    u = floe.u + floe.ξ * (x - floe.centroid[1])
    v = floe.v + floe.ξ * (y - floe.centroid[2])
    return u, v
end

"""
    get_velocity(
        element::AbstractDomainElement{FT},
        x,
        y,
    )

Get velocity, which is 0m/s by default, of a point on topography element or
boundary. 
"""
get_velocity(
    element::AbstractDomainElement{FT},
    _,
    _,
) where {FT} = 
    FT(0), FT(0)

get_velocity(
    element::MovingBoundary,
    _,
    _,
) = element.u, element.v

"""
    calc_friction_forces(
        ifloe,
        jfloe,
        fpoints,
        normal::Matrix{FT},
        Δl,
        consts,
        Δt,
    )
Calculate frictional force for collision between two floes or a floe and a
domain element.
Input:
    ifloe   <Floe> first floe in collsion
    jfloe   <Union{Floe, DomainElement}> either second floe or topography
                element/boundary element
    fpoints <Array{Float, N, 2}> x,y-coordinates of the point the force is
                applied on floe overlap region
    normal  <Array{Float, N, 2}> x,y normal force applied on fpoint on floe
                overlap region
    Δl      <Vector> mean length of distance between intersection points
    consts  <Constants> model constants needed for calculations
    Δt      <AbstractFloat> simulation's timestep
Outputs:
    force   <Array{Float, N, 2}> frictional/tangential force of the collision in
                x and y (each row) for each collision (each column)
"""
function calc_friction_forces(
    ifloe,
    jfloe,  # could be a boundary or a topography
    fpoints,
    normal::Matrix{FT},
    Δl,
    consts,
    Δt,
) where {FT}
    force = zeros(FT, size(fpoints, 1), 2)
    G = consts.E/(2*(1+consts.ν))
    for i in axes(fpoints, 1)
        px = fpoints[i, 1]
        py = fpoints[i, 2]
        nnorm = sqrt(normal[i, 1]^2 + normal[i, 2]^2)
        iu, iv = get_velocity(ifloe, px, py)
        ju, jv = get_velocity(jfloe, px, py)

        udiff = iu - ju
        vdiff = iv - jv

        vnorm = sqrt(udiff^2 + vdiff^2)
        xdir = FT(0)
        ydir = FT(0)
        if udiff != 0 || vdiff != 0
            xdir = udiff/vnorm
            ydir = vdiff/vnorm
        end
        dot_dir = xdir * udiff + ydir * vdiff
        xfriction = G *  Δl[i] * Δt * nnorm * xdir * -dot_dir
        yfriction = G *  Δl[i] * Δt * nnorm * ydir * -dot_dir
        norm_fric = sqrt(xfriction^2 + yfriction^2)
        if norm_fric > consts.μ * nnorm
            xfriction = -consts.μ * nnorm * xdir
            yfriction = -consts.μ * nnorm * ydir
        end
        force[i, 1] = xfriction
        force[i, 2] = yfriction
    end
    return force
end

function add_interactions!(np, ifloe, idx::FT, forces, points, overs) where FT
    inter_spots = size(ifloe.interactions, 1) - ifloe.num_inters
    @views for i in 1:np
        if forces[i, 1] != 0 || forces[i, 2] != 0
            ifloe.num_inters += 1
            if inter_spots < 1
                ifloe.interactions = vcat(
                    ifloe.interactions,
                    zeros(FT, np - i + 1 , 7)
                )
                inter_spots += np - i
            end
            ifloe.interactions[ifloe.num_inters, floeidx] = idx
            ifloe.interactions[ifloe.num_inters, xforce:yforce] .=
                forces[i, :]
            ifloe.interactions[ifloe.num_inters, xpoint:ypoint] .=
                points[i, :]
            ifloe.interactions[ifloe.num_inters, torque] = FT(0)
            ifloe.interactions[ifloe.num_inters, overlap] = overs[i]
            ifloe.overarea += overs[i]
            inter_spots -= 1
        end
    end
    return
end

"""
    floe_floe_interaction!(
        ifloe,
        i,
        jfloe,
        j,
        nfloes,
        consts,
        Δt,
    )

If the two floes interact, update floe i's interactions accordingly. Floe j is
not update here so that the function can be parallelized.
Inputs:
    ifloe       <Floe> first floe in potential interaction
    i           <Int> index of ifloe in model's list of floes 
    jfloe       <Floe> second floe in potential interaction
    j           <Int> index of jfloe in model's list of floes 
    nfloes      <Int> number of non-ghost floes in the simulation this timestep
    consts      <Constants> model constants needed for calculations
    Δt          <Int> Simulation's current timestep
    max_overlap <Float> Percent two floes can overlap before marking them
                        for fusion
Outputs:
    None. Updates floes interactions fields. If floes overlap by more than
    the max_overlap fraction, they will be marked for fusion.
Note:
    If ifloe interacts with jfloe, only ifloe's interactions field is updated
    with the details of each region of overlap. The interactions field will have
    the following form for each region of overlap with the boundary:
    [Inf, xforce, yforce, xfpoints, yfpoints, overlaps] where the xforce and
    yforce are the forces, xfpoints and yfpoints are the location of the force
    and overlaps is the overlap between the floe and boundary. The overlaps
    field is also added to the floe's overarea field that describes the total
    overlapping area at any timestep. 
"""
function floe_floe_interaction!(
    ifloe,
    i,
    jfloe,
    j,
    consts,
    Δt,
    max_overlap::FT,
) where {FT<:AbstractFloat}
    inter_regions = intersect_polys(make_polygon(ifloe.coords), make_polygon(jfloe.coords))
    region_areas = Vector{FT}(undef, length(inter_regions))
    total_area = FT(0)
    for i in eachindex(inter_regions)
        a = FT(GO.area(inter_regions[i]))
        region_areas[i] = a
        total_area += a
    end
    if total_area > 0
        # Floes overlap too much - mark floes to be fused
        if max(total_area/ifloe.area, total_area/jfloe.area) > max_overlap
            ifloe.status.tag = fuse
            push!(ifloe.status.fuse_idx, j)
        else
            # Constant needed to calculate force
            ih = ifloe.height
            ir = FT(sqrt(ifloe.area))
            jh = jfloe.height
            jr = FT(sqrt(jfloe.area))
            force_factor = if ir>1e5 || jr>1e5
                consts.E*min(ih, jh)/min(ir, jr)
            else
                consts.E*(ih*jh)/(ih*jr+jh*ir)
            end
            # Calculate normal forces, force points, and overlap areas
            normal_forces, fpoints, overlaps, Δl = calc_elastic_forces(
                ifloe.coords,
                jfloe.coords,
                inter_regions,
                region_areas,
                force_factor
            )
            #= Calculate frictional forces at each force point - based on
            velocities at force points =#
            np = size(fpoints, 1)
            if np > 0
                friction_forces = calc_friction_forces(
                    ifloe,
                    jfloe,
                    fpoints,
                    normal_forces,
                    Δl,
                    consts,
                    Δt,
                )
                # Calculate total forces and update ifloe's interactions
                forces = normal_forces .+ friction_forces
                add_interactions!(np, ifloe, j, forces, fpoints, overlaps)
            end
        end
    end
    return
end

"""
    floe_domain_element_interaction!(floe, boundary, _, _,)

If given floe insersects with an open boundary, the floe is set to be removed
from the simulation.
Inputs:
    floe            <Floe> floe interacting with boundary
    boundary        <OpenBoundary> coordinates of boundary
    _               <Constants> model constants needed in other methods of this
                        function - not needed here
    _               <Int> current simulation timestep - not needed here
    -               <Float> maximum overlap between floe and domain elements -
                        not needed here
Output:
    None. If floe is interacting with the boundary, floe's status is set to
    remove. Else, nothing is changed. 
"""
function floe_domain_element_interaction!(
    floe,
    boundary::OpenBoundary,
    element_idx,
    consts,
    Δt,
    max_overlap,
)
    floe_poly = make_polygon(floe.coords)
    bounds_poly = make_polygon(boundary.coords)
    # Check if the floe and boundary actually overlap
    inter_area = sum(GO.area, intersect_polys(floe_poly, bounds_poly); init = 0.0)
    if inter_area > 0
        floe.status.tag = remove
    end
    return
end

"""
    floe_domain_element_interaction!(
        floe,
        ::PeriodicBoundary,
        element_idx,
        consts,
        Δt,
    )

If a given floe intersects with a periodic boundary, nothing happens at this
point. Periodic floes pass through boundaries using ghost floes.
Inputs:
        None are used. 
Output:
        None. This function does not do anyting. 
"""
function floe_domain_element_interaction!(
    floe,
    ::PeriodicBoundary,
    element_idx,
    consts,
    Δt,
    max_overlap,
)
    return
end

"""
    normal_direction_correct!(
        forces,
        fpoints,
        boundary::AbstractBoundary{North, <:AbstractFloat},
    )

Zero-out forces that point in direction not perpendicular to North boundary wall.
Inputs:
    force       <Array{Float, n, 2}> normal forces on each of the n regions
                    greater than a minimum area
    fpoint      <Array{Float, n, 2}> point force is applied on each of the n
                    regions greater than a minimum area
    boundary    <AbstractBoundary{North, <:AbstractFloat}> domain's northern
                    boundary
Outputs:
    None. All forces in the x direction set to 0 if the point the force is
    applied to is in the northern boundary.
"""
function normal_direction_correct!(
    forces::Matrix{FT},
    fpoints,
    boundary::AbstractBoundary{North, <:AbstractFloat},
) where {FT}
    forces[fpoints[:, 2] .>= boundary.val, 1] .= FT(0.0)
    return
end

"""
    normal_direction_correct!(
        forces,
        fpoints,
        boundary::AbstractBoundary{South, <:AbstractFloat},
    )

Zero-out forces that point in direction not perpendicular to South boundary wall.
See normal_direction_correct! on northern wall for more information
"""
function normal_direction_correct!(
    forces::Matrix{FT},
    fpoints,
    boundary::AbstractBoundary{South, <:AbstractFloat},
) where {FT}
        forces[fpoints[:, 2] .<= boundary.val, 1] .= FT(0.0)
        return
    end

"""
    normal_direction_correct!(
        forces,
        fpoints,
        boundary::AbstractBoundary{East, <:AbstractFloat},
    )

Zero-out forces that point in direction not perpendicular to East boundary wall.
See normal_direction_correct! on northern wall for more information
"""
function normal_direction_correct!(
    forces::Matrix{FT},
    fpoints,
    boundary::AbstractBoundary{East, <:AbstractFloat},
) where {FT}
    forces[fpoints[:, 1] .>= boundary.val, 2] .= FT(0.0)
    return
end

"""
    normal_direction_correct!(
        forces,
        fpoints,
        boundary::AbstractBoundary{<:AbstractFloat, West},
    )

Zero-out forces that point in direction not perpendicular to West boundary wall.
See normal_direction_correct! on northern wall for more information
"""
function normal_direction_correct!(
    forces::Matrix{FT},
    fpoints,
    boundary::AbstractBoundary{West, <:AbstractFloat},
) where {FT}
    forces[fpoints[:, 1] .<= boundary.val, 2] .= FT(0.0)
    return
end

"""
    normal_direction_correct!(
        forces,
        fpoints,
        ::TopographyElement,
    )

No forces should be zero-ed out in collidions with topography elements. 
Inputs:
        None used.
Outputs:
        None.
"""
function normal_direction_correct!(
    forces,
    fpoints,
    ::TopographyElement,
)
    return
end

"""
    floe_domain_element_interaction!(
        floe,
        element,
        element_idx,
        consts,
        Δt,
    )

If floe intersects with given element (either collision boundary or
topography element), floe interactions field and overarea field are updated.
Inputs:
    floe            <Floe> floe interacting with element
    element         <Union{CollisionBoundary, TopographyElement}> coordinates of
                        element
    consts          <Constants> model constants needed for calculations
    Δt              <Int> current simulation timestep
    max_overlap     <Float> Percent a floe can overlap with a collision wall
                            or topography before being killed/removed
Outputs:
    None. If floe interacts, the floe's interactions field is updated with the
    details of each region of overlap. The interactions field will have the
    following form for each region of overlap with the element:
    [Inf, xforce, yforce, xfpoints, yfpoints, overlaps] where the xforce and
    yforce are the forces, xfpoints and yfpoints are the location of the force
    and overlaps is the overlap between the floe and element. The overlaps field
    is also added to the floe's overarea field that describes the total
    overlapping area at any timestep.
"""
function floe_domain_element_interaction!(
    floe,
    element::Union{
        CollisionBoundary,
        MovingBoundary,
        TopographyElement,
    },
    elem_idx,
    consts,
    Δt,
    max_overlap::FT,
) where {FT}
    inter_regions = intersect_polys(make_polygon(floe.coords), make_polygon(element.coords))
    region_areas = Vector{FT}(undef, length(inter_regions))
    max_area = FT(0)
    for i in eachindex(inter_regions)
        a = GO.area(inter_regions[i], FT)
        region_areas[i] = a
        if a > max_area
            max_area = a
        end
    end

    if max_area > 0
        # Regions overlap too much
        if maximum(region_areas)/floe.area > max_overlap
            floe.status.tag = remove
        else
            # Constant needed for force calculations
            force_factor = consts.E * floe.height / sqrt(floe.area)
            # Calculate normal forces, force points, and overlap areas
            normal_forces, fpoints, overlaps, Δl =  calc_elastic_forces(
                floe.coords,
                element.coords,
                inter_regions,
                region_areas,
                force_factor,
            )
            normal_direction_correct!(normal_forces, fpoints, element)
            # Calculate frictional forces at each force point
            np = size(fpoints, 1)
            if np > 0
                friction_forces = calc_friction_forces(
                    floe,
                    element,
                    fpoints,
                    normal_forces,
                    Δl,
                    consts,
                    Δt,
                )
                # Calculate total forces and update ifloe's interactions
                forces = normal_forces .+ friction_forces
                add_interactions!(np, floe, elem_idx, forces, fpoints, overlaps)
            end
        end
    end
    return
end

"""
    update_boundary!(args...)

No updates to boundaries that aren't compression boundaries.
"""
function update_boundary!(
    boundary::Union{OpenBoundary, CollisionBoundary, PeriodicBoundary},
    Δt,
)
    return
end
"""
    update_boundary!(boundary, Δt)

Move North/South compression boundaries by given velocity. Update coords and val
fields to reflect new position.
Inputs:
    boundary    <MovingBoundary{Union{North, South}, AbstractFloat}> 
                    domain compression boundary
    Δt          <Int> number of seconds in a timestep
Outputs:
    None. Move boundary North or South depending on velocity.
"""
function update_boundary!(
    boundary::MovingBoundary{D, FT},
    Δt,
) where {D <: Union{North, South}, FT <: AbstractFloat}
    Δd = boundary.v * Δt
    boundary.val += Δd
    translate!(boundary.coords, FT(0), Δd)
end
"""
    update_boundary!(boundary, Δt)

Move East/West compression boundaries by given velocity. Update coords and val
fields to reflect new position.
Inputs:
    boundary    <MovingBoundary{Union{East, West}, AbstractFloat}> 
                    domain compression boundary
    Δt          <Int> number of seconds in a timestep
Outputs:
    None. Move boundary East/West depending on velocity.
"""
function update_boundary!(
    boundary::MovingBoundary{D, FT},
    Δt,
) where {D <: Union{East, West}, FT <: AbstractFloat}
    Δd = boundary.u * Δt
    boundary.val += Δd
    translate!(boundary.coords, Δd, FT(0))
end

"""
    update_boundaries!(domain)
    
Update each boundary in the domain. For now, this simply means moving
compression boundaries by their velocities. 
"""
function update_boundaries!(domain, Δt)
    update_boundary!(domain.north, Δt)
    update_boundary!(domain.south, Δt)
    update_boundary!(domain.east, Δt)
    update_boundary!(domain.west, Δt)
end

"""
    floe_domain_interaction!(
        floe,
        domain::DT,
        consts,
        max_overlap,
    )

If the floe interacts with the domain, update the floe accordingly. Dispatches
on different boundary types within the domain.
Inputs:
    floe        <Floe> floe interacting with boundary
    domain      <Domain> model domain
    consts      <Constants> model constants needed for calculations
    Δt          <Int> current simulation timestep
    max_overlap <Float> Percent a floe can overlap with a collision wall
                        or topography before being killed/removed
Outputs:
    None. Floe is updated according to which boundaries it interacts with and
    the types of those boundaries. 
"""
function floe_domain_interaction!(
    floe,
    domain::Domain,
    consts,
    Δt,
    max_overlap::FT,
) where {FT<:AbstractFloat}
    centroid = floe.centroid
    rmax = floe.rmax
    nbound = domain.north
    sbound = domain.south
    ebound = domain.east
    wbound = domain.west

    if centroid[2] + rmax > nbound.val
        floe_domain_element_interaction!(
            floe,
            nbound,
            -1,
            consts,
            Δt,
            max_overlap,
        )
    end
    if centroid[2] - rmax < sbound.val
        floe_domain_element_interaction!(
            floe,
            sbound,
            -2,
            consts,
            Δt,
            max_overlap,
        )
    end
    if centroid[1] + rmax > ebound.val
        floe_domain_element_interaction!(
            floe,
            ebound,
            -3,
            consts,
            Δt,
            max_overlap,
        )
    end
    if centroid[1] - rmax < wbound.val
        floe_domain_element_interaction!(
            floe,
            wbound,
            -4,
            consts,
            Δt,
            max_overlap,
        )
    end

    for (i, topo_element) in enumerate(domain.topography)
        if sum((topo_element.centroid .- floe.centroid).^2) < (topo_element.rmax + floe.rmax)^2
            floe_domain_element_interaction!(
                floe,
                topo_element,
                -(4 + i),
                consts,
                Δt,
                max_overlap,
            )
        end
    end
    return
end

"""
    calc_torque!(floe)

Calculate a floe's torque based on the interactions.
Inputs:
        floe  <Floe> floe in model
Outputs:
        None. Floe's interactions field is updated with calculated torque.
"""
function calc_torque!(
    floe::Union{LazyRow{<:Floe{FT}}, Floe{FT}},
) where {FT<:AbstractFloat}
    inters = floe.interactions
    for i in 1:floe.num_inters
        xp = inters[i, xpoint] .- floe.centroid[1]
        yp = inters[i, ypoint] .- floe.centroid[2]
        xf = inters[i, xforce]
        yf = inters[i, yforce]
        # cross product of direction and force where third element of both is 0
        floe.interactions[i, torque] = xp * yf - yp * xf
    end
    return
end

"""
    potential_interaction(
        centroid1,
        centroid2,
        rmax1,
        rmax2,
    )
Determine if two floes could potentially interact using the two centroid and two
radii to form a bounding circle.
Inputs:
    centroid1   <Vector> first floe's centroid [x, y]
    centroid2   <Vector> second floe's centroid [x, y]
    rmax1       <Float> first floe's maximum radius
    rmax2       <Float> second floe's maximum radius
Outputs:
    <Bool> true if floes could potentially interact, false otherwise
"""
potential_interaction(
    centroid1,
    centroid2,
    rmax1,
    rmax2,
) = ((centroid1[1] - centroid2[1])^2 + (centroid1[2] - centroid2[2])^2) < 
    (rmax1 + rmax2)^2

"""
    timestep_collisions!(
        floes,
        n_init_floes,
        domain,
        consts,
        Δt,
        collision_settings,
        spinlock,
    )

Resolves collisions between pairs of floes and calculates the forces and torques
caused by those collisions.
Inputs:
    floes               <StructArray{Floe}> model's list of floes
    n_init_floes        <Int> number of floes without ghost floes
    domain              <Domain> model's domain
    consts              <Constants> simulation constants
    Δt                  <Int> length of simulation timestep in seconds
    collision_settings  <CollisionSettings> simulation collision settings
    spinlock            <Thread.SpinLock>
"""
function timestep_collisions!(
    floes::StructArray{<:Floe{FT}},
    n_init_floes,
    domain,
    consts,
    Δt,
    collision_settings,
    spinlock,
) where {FT<:AbstractFloat}
    collide_pairs = Dict{Tuple{Int, Int}, Tuple{Int, Int}}()
    # floe-floe collisions for floes i and j where i<j
    Threads.@threads for i in eachindex(floes)
        # reset collision values
        fill!(floes.collision_force[i], FT(0))
        floes.collision_trq[i] = FT(0.0)
        floes.num_inters[i] = 0
        for j in i+1:length(floes)
            id_pair, ghost_id_pair =
                if floes.id[i] > floes.id[j]
                    (floes.id[i], floes.id[j]), (floes.ghost_id[i], floes.ghost_id[j])
                else
                    (floes.id[j], floes.id[i]), (floes.ghost_id[j], floes.ghost_id[i])
                end
            # If checking two distinct floes (i.e. not a parent ghost pair) and they are in close proximity continue
            if (id_pair[1] != id_pair[2]) && potential_interaction(
                floes.centroid[i],
                floes.centroid[j],
                floes.rmax[i],
                floes.rmax[j],
            )
                # Add floes/ghosts to collision list if they didn't exist before
                (g1, g2) = Threads.lock(spinlock) do
                    get!(collide_pairs, id_pair, ghost_id_pair)
                end
                #=
                    New collision or floe and ghost colliding with same floe ->
                    not a repeat collision
                =#
                if (
                    (ghost_id_pair[1] == g1) && (ghost_id_pair[2] == g2) ||
                    (ghost_id_pair[1] == g1) ⊻ (ghost_id_pair[2] == g2)
                )
                    floe_floe_interaction!(
                        LazyRow(floes, i),
                        i,
                        LazyRow(floes, j),
                        j,
                        consts,
                        Δt,
                        collision_settings.floe_floe_max_overlap,
                    )
                end
            end
        end
        floe_domain_interaction!(
            LazyRow(floes, i),
            domain,
            consts,
            Δt,
            collision_settings.floe_domain_max_overlap,
        )
    end
    # Move compression boundaries if they exist
    update_boundaries!(domain, Δt)
    # Update floes not directly calculated above where i>j - can't be parallel
    for i in eachindex(floes)
        # Update fuse information
        if floes.status[i].tag == fuse
            for idx in floes.status[i].fuse_idx
                floes.status[idx].tag = fuse
                push!(floes.status[idx].fuse_idx, i)
            end
        end
        # Update interaction information
        i_inters = floes.interactions[i]
        if floes.num_inters[i] > 0
            # Loop over each interaction with floe i
            for inter_idx in 1:floes.num_inters[i]
                j = i_inters[inter_idx, floeidx]  # Index of floe to update
                # not boundaries and hasn't been updated yet
                if j <= length(floes) && j > i
                    jidx = Int(j)
                    # add matching interaction (j with i)
                    add_interactions!(1, LazyRow(floes, jidx), FT(i),
                        i_inters[inter_idx:inter_idx, xforce:yforce],
                        i_inters[inter_idx:inter_idx, xpoint:ypoint],
                        i_inters[inter_idx:inter_idx, overlap:overlap]
                    )
                    # equal and opposite forces
                    j_np = floes.num_inters[jidx]
                    floes.interactions[jidx][j_np, xforce:yforce] *= -1
                end
            end
        end
    end
    # Calculate total on parents by summing interactions on parent and children
    for i in 1:n_init_floes
        if !isempty(floes.ghosts[i])
            for g in floes.ghosts[i]
                gnp = floes.num_inters[g]
                # shift interaction points to parent locations
                floes.interactions[g][1:gnp, xpoint] .-=
                    floes.centroid[g][1] - floes.centroid[i][1]
                floes.interactions[g][1:gnp, ypoint] .-=
                    floes.centroid[g][2] - floes.centroid[i][2]
                # add interactions
                add_interactions!(gnp, LazyRow(floes, i), i,
                    floes.interactions[g][1:gnp, xforce:yforce],
                    floes.interactions[g][1:gnp, xpoint:ypoint],
                    floes.interactions[g][1:gnp, overlap]
                )
                inp = floes.num_inters[i]
                # set interaction indices to correct values
                floes.interactions[i][(inp - gnp + 1):inp, floeidx] .= 
                    floes.interactions[g][1:gnp, floeidx]
            end
        end
        # calculate interactions torque and total forces / torque
        calc_torque!(LazyRow(floes, i))
        floes.collision_force[i][1] += sum(
            @view floes.interactions[i][1:floes.num_inters[i], xforce]
        )
        floes.collision_force[i][2] += sum(
            @view floes.interactions[i][1:floes.num_inters[i], yforce]
        )
        floes.collision_trq[i] += sum(
            @view floes.interactions[i][1:floes.num_inters[i], torque]
        )
    end
    return
end

"""
    ghosts_on_bounds(element, ghosts, boundary, trans_vec)

If the given element intersects with the boundary, add ghosts of the element and 
any of its existing ghosts. 
Inputs:
    floes       <StructArray{Floe}> model's list of floes
    elem_idx    <Int> floe of interest's index within the floe list
    boundary    <PeriodicBoundary> boundary to translate element through
    trans_vec   <Matrix{Float}> 1x2 matrix of form [x y] to translate element
                    through the boundary
Outputs:
    Nothing. New ghosts created by the given element, or its current ghosts,
    are added to the floe list
"""
function ghosts_on_bounds!(
    floes,
    elem_idx,
    boundary,
    trans_vec,
)
    nfloes = length(floes)
    nghosts = 1
    if !isempty(intersect_polys(make_polygon(floes.coords[elem_idx]), make_polygon(boundary.coords)))
        # ghosts of existing ghosts and original element
        for i in floes.ghosts[elem_idx]
            push!(
                floes,
                deepcopy_floe(LazyRow(floes, i)),
            )
            nghosts += 1
        end
        push!(
                floes,
                deepcopy_floe(LazyRow(floes, elem_idx)),
            )
        for i in (nfloes + 1):(nfloes + nghosts)
            translate!(floes.coords[i], trans_vec[1], trans_vec[2])
            floes.centroid[i] .+= trans_vec
        end
    end
    return
end

"""
    find_ghosts(
        floes,
        elem_idx,
        ebound::PeriodicBoundary,
        wbound::PeriodicBoundary,
    )

Find ghosts of given element and its known ghosts through an eastern or western
periodic boundary. If element's centroid isn't within the domain in the
east/west direction, swap it with its ghost since the ghost's centroid must then
be within the domain. 
Inputs:
    floes       <StructArray{Floe}> model's list of floes
    elem_idx    <Int> floe of interest's index within the floe list
    eboundary   <PeriodicBoundary{East, Float}> domain's eastern boundary
    wboundary   <PeriodicBoundary{West, Float}> domain's western boundary
Outputs:
    None. Ghosts added to the floe list. Primary floe always has centroid within
    the domain, else it is swapped with one of its ghost's which has a centroid
    within the domain.
"""
function find_ghosts(
    floes,
    elem_idx,
    ebound::PeriodicBoundary{East, FT},
    wbound::PeriodicBoundary{West, FT},
) where {FT <: AbstractFloat}
    Lx = ebound.val - wbound.val
    nfloes = length(floes)
    # passing through western boundary
    if (floes.centroid[elem_idx][1] - floes.rmax[elem_idx] < wbound.val)
        ghosts_on_bounds!(
            floes,
            elem_idx,
            wbound,
            [Lx, FT(0)],
        )
    # passing through eastern boundary
    elseif (floes.centroid[elem_idx][1] + floes.rmax[elem_idx] > ebound.val)
        ghosts_on_bounds!(
            floes,
            elem_idx,
            ebound,
            [-Lx, FT(0)],
        )
    end
    # if element centroid isn't in domain's east/west direction, swap with ghost
    if length(floes) > nfloes
        if floes.centroid[elem_idx][1] < wbound.val
            translate!(floes.coords[elem_idx], Lx, FT(0))
            floes.centroid[elem_idx][1] += Lx
            translate!(floes.coords[end], -Lx, FT(0))
            floes.centroid[end][1] -= Lx
        elseif ebound.val < floes.centroid[elem_idx][1]
            translate!(floes.coords[elem_idx], -Lx, FT(0))
            floes.centroid[elem_idx][1] -= Lx
            translate!(floes.coords[end], Lx, FT(0))
            floes.centroid[end][1] += Lx
        end
    end
    return
end

"""
    find_ghosts(
        floes,
        elem_idx,
        nbound::PeriodicBoundary{North, <:AbstractFloat},
        sbound::PeriodicBoundary{South, <:AbstractFloat},
    )

Find ghosts of given element and its known ghosts through an northern or
southern periodic boundary. If element's centroid isn't within the domain in the
north/south direction, swap it with its ghost since the ghost's centroid must
then be within the domain. 
Inputs:
    floes       <StructArray{Floe}> model's list of floes
    elem_idx    <Int> floe of interest's index within the floe list
    nboundary        <PeriodicBoundary{North, Float}> domain's northern boundary
    sboundary        <PeriodicBoundary{South, Float}> domain's southern boundary
Outputs:
    None. Ghosts added to the floe list. Primary floe always has centroid within
    the domain, else it is swapped with one of its ghost's which has a centroid
    within the domain.
"""
function find_ghosts(
    floes,
    elem_idx,
    nbound::PeriodicBoundary{North, FT},
    sbound::PeriodicBoundary{South, FT},
) where {FT <: AbstractFloat}
    Ly =  nbound.val - sbound.val
    nfloes = length(floes)
        # passing through southern boundary
    if (floes.centroid[elem_idx][2] - floes.rmax[elem_idx] < sbound.val)
        ghosts_on_bounds!(
            floes,
            elem_idx,
            sbound,
            [FT(0), Ly],
        )
    # passing through northern boundary
    elseif (floes.centroid[elem_idx][2] + floes.rmax[elem_idx] > nbound.val) 
        ghosts_on_bounds!(
            floes,
            elem_idx,
            nbound,
            [FT(0), -Ly],
        )
    end
    # if element centroid isn't in domain's north/south direction, swap with ghost
    if length(floes) > nfloes
        if floes.centroid[elem_idx][2] < sbound.val
            translate!(floes.coords[elem_idx], FT(0), Ly)
            floes.centroid[elem_idx][2] += Ly
            translate!(floes.coords[end], FT(0), -Ly)
            floes.centroid[end][2] -= Ly
        elseif nbound.val < floes.centroid[elem_idx][2]
            translate!(floes.coords[elem_idx], FT(0), -Ly)
            floes.centroid[elem_idx][2] -= Ly
            translate!(floes.coords[end], FT(0), Ly)
            floes.centroid[end][2] += Ly
        end
    end
    return
end

"""
    add_floe_ghosts!(floes, max_boundary, min_boundary)

Add ghosts of all of the given floes passing through the two given boundaries to
the list of floes.
Inputs:
    floes           <StructArray{Floe{FT}}> list of floes to find ghosts for
    max_boundary    <PeriodicBoundary> northern or eastern boundary of domain
    min_boundary    <PeriodicBoundary> southern or western boundary of domain
Outputs:
    None. Ghosts of floes are added to floe list. 
"""
function add_floe_ghosts!(
    floes::FLT,
    max_boundary,
    min_boundary,
) where {FT <: AbstractFloat, FLT <: StructArray{<:Floe{FT}}}
    nfloes = length(floes)
    # uses initial length of floes so we can append to list
    for i in eachindex(floes)
        # the floe is active in the simulation and a parent floe
        if floes.status[i].tag == active && floes.ghost_id[i] == 0
            find_ghosts(
                floes,
                i,
                max_boundary,
                min_boundary,
            )
            new_nfloes = length(floes)
            if new_nfloes > nfloes
                nghosts = new_nfloes - nfloes
                # set ghost floe's ghost id
                floes.ghost_id[(nfloes + 1):new_nfloes] .= range(1, nghosts) .+ length(floes.ghosts[i])
                # remove ghost floes ghosts as these were added to parent
                empty!.(floes.ghosts[nfloes + 1:new_nfloes])
                # index of ghosts floes saved in parent
                append!(floes.ghosts[i], (nfloes + 1):(nfloes + nghosts))
                nfloes += nghosts
            end
        end
    end
    return
end
"""
    add_ghosts!(
        elems,
        domain,
    )

When there are no periodic boundaries, no ghosts should be added.
Inputs:
        None are used. 
Outputs:
        None. 
"""
function add_ghosts!(
    elems,
    ::Domain{
        FT,
        <:NonPeriodicBoundary,
        <:NonPeriodicBoundary,
        <:NonPeriodicBoundary,
        <:NonPeriodicBoundary,
    },
) where {FT<:AbstractFloat}
    return
end

"""
    add_ghosts!(
        elems,
        domain,
    )

Add ghosts for elements that pass through the northern or southern boundaries.
Inputs:
        elems   <StructArray{Floe} or StructArray{TopographyElement}> list of
                    elements to add ghosts to
        domain  <Domain{
                    Float,
                    PeriodicBoundary,
                    PeriodicBoundary,
                    NonPeriodicBoundary,
                    NonPeriodicBoundary,
                }> domain with northern and southern periodic boundaries
Outputs:
        None. Ghosts are added to list of elements.
"""
function add_ghosts!(
    elems,
    domain::Domain{
        FT,
        <:PeriodicBoundary,
        <:PeriodicBoundary,
        <:NonPeriodicBoundary,
        <:NonPeriodicBoundary,
    },
) where {FT<:AbstractFloat}
    add_floe_ghosts!(elems, domain.north, domain.south)
    return
end

"""
    add_ghosts!(
        elems,
        domain,
    )

Add ghosts for elements that pass through the eastern or western boundaries. 
Inputs:
    elems   <StructArray{Floe} or StructArray{TopographyElement}> list of
                elements to add ghosts to
    domain  <Domain{
                Float,
                NonPeriodicBoundary,
                NonPeriodicBoundary,
                PeriodicBoundary,
                PeriodicBoundary,
            }> domain with eastern and western periodic boundaries 
Outputs:
    None. Ghosts are added to list of elements.
"""
function add_ghosts!(
    elems,
    domain::Domain{
        FT,
        <:NonPeriodicBoundary,
        <:NonPeriodicBoundary,
        <:PeriodicBoundary,
        <:PeriodicBoundary,
    },
) where {FT<:AbstractFloat}
    add_floe_ghosts!(elems, domain.east, domain.west)
    return
end

"""
    add_ghosts!(
        elems,
        domain,
    )

Add ghosts for elements that pass through any of the boundaries. 
Inputs:
    elems   <StructArray{Floe} or StructArray{TopographyElement}> list of
                elements to add ghosts to
    domain  <Domain{
                AbstractFloat,
                PeriodicBoundary,
                PeriodicBoundary,
                PeriodicBoundary,
                PeriodicBoundary,
            }> domain with all boundaries
Outputs:
        None. Ghosts are added to list of elements.
"""
function add_ghosts!(
    elems,
    domain::Domain{
        FT,
        <:PeriodicBoundary,
        <:PeriodicBoundary,
        <:PeriodicBoundary,
        <:PeriodicBoundary
    }
) where {FT<:AbstractFloat}
    add_floe_ghosts!(elems, domain.east, domain.west)
    add_floe_ghosts!(elems, domain.north, domain.south)
    return
end
