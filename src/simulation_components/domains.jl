# Cardinal directions
export AbstractDirection, North, South, East, West
# Boundary of the model - property of each of the 4 walls (north, south, east, west)
export AbstractBoundary, OpenBoundary, PeriodicBoundary, CollisionBoundary, MovingBoundary
# Topographic element within domain
export TopographyElement
# Domain definition (combines 4 boundaries and topography)
export Domain

"""
    YourDirection <: AbstractDirection

Each domain within a Subzero.jl [`Model`](@ref) must have four (4) boundaries (subtypes
of [`AbstractBoundary`](@ref)) where each of these boundaries is parametrically typed by the
direction of the boundary. The user will first choose one of the four cardinal directions,
the subtypes of `AbstractDirection`:
- [`North`](@ref)
- [`South`](@ref)
- [`East`](@ref)
- [`West`](@ref)

This abstract type is not meant to be extended by the user, unless the user wants to move
away from a rectangular domain with assigned cardinal directions for each wall. This would
a more major redesign and the user should check out the [developer documentation]("devdocs.md").
"""
abstract type AbstractDirection end

"""
    North<:AbstractDirection

A simple subtype of [`AbstractDirection`](@ref) used for parametrically typing a subtype of
[`AbstractBoundary`](@ref) if that boundary is the northern boundary in a rectangular domain.
"""
struct North<:AbstractDirection end

#=
    _grid_boundary_info(FT, North, grid)

Create a bounding box polygon representing the Northern boundary of a rectangular grid with
points of float type `FT`. If the length of the grid x-extent is `Lx = xf - x0` then the
x-extent of the boundary polygon will range from `x0 - Lx/2` to `xf + Lx/2` in the x-direction.
If the length of the grid y-extent is `Ly = yf - y0` then the boundary polygon will range from
`yf` to `yf + Ly/2` in the y-direction. This will create overlap with other boundary walls,
if all created from the grid, making sure all floes connect with boundaries at edges of
the domain.

Also return value `yf` as the value representing the edge of the boundary connecting with
the edge of the domain.
=#
function _grid_boundary_info(::Type{FT}, ::Type{North}, grid::RegRectilinearGrid) where FT
    Δx = (grid.xf - grid.x0)/2
    Δy = (grid.yf - grid.y0)/2
    poly =  _make_bounding_box_polygon(FT, grid.x0 - Δx, grid.xf + Δx, grid.yf, grid.yf + Δy)
    return poly, grid.yf
end

"""
    South<:AbstractDirection

A simple subtype of [`AbstractDirection`](@ref) used for parametrically typing a subtype of
[`AbstractBoundary`](@ref) if that boundary is the southern boundary in a rectangular domain.
"""
struct South<:AbstractDirection end

#=
    _grid_boundary_info(FT, South, grid)

Create a bounding box polygon representing the Southern boundary of a rectangular grid with
points of float type `FT`. If the length of the grid x-extent is `Lx = xf - x0` then the
x-extent of the boundary polygon will range from `x0 - Lx/2` to `xf + Lx/2` in the x-direction.
If the length of the grid y-extent is `Ly = yf - y0` then the boundary polygon will range from
`y0 - Ly/2` to `y0` in the y-direction. This will create overlap with other boundary walls,
if all created from the grid, making sure all floes connect with boundaries at edges of
the domain.

Also return value `y0` as the value representing the edge of the boundary connecting with
the edge of the domain.
=#
function _grid_boundary_info(::Type{FT}, ::Type{South}, grid::RegRectilinearGrid) where FT
    Δx = (grid.xf - grid.x0)/2
    Δy = (grid.yf - grid.y0)/2
    poly = _make_bounding_box_polygon(FT, grid.x0 - Δx, grid.xf + Δx, grid.y0 - Δy, grid.y0)
    return poly, grid.y0
end


"""
    East<:AbstractDirection


A simple subtype of [`AbstractDirection`](@ref) used for parametrically typing a subtype of
[`AbstractBoundary`](@ref) if that boundary is the eastern boundary in a rectangular domain.
"""
struct East<:AbstractDirection end

#=
    _grid_boundary_info(FT, East, grid)

Create a bounding box polygon representing the Eastern boundary of a rectangular grid with
points of float type `FT`. If the length of the grid x-extent is `Lx = xf - x0` then the
x-extent of the boundary polygon will range from `xf` to `xf + Lx/2` in the x-direction.
If the length of the grid y-extent is `Ly = yf - y0` then the boundary polygon will range from
`y0 - Ly/2` to `yf + Ly/2` in the y-direction. This will create overlap with other boundary walls,
if all created from the grid, making sure all floes connect with boundaries at edges of
the domain.

Also return value `xf` as the value representing the edge of the boundary connecting with
the edge of the domain.
=#
function _grid_boundary_info(::Type{FT}, ::Type{East}, grid::RegRectilinearGrid) where FT
    Δx = (grid.xf - grid.x0)/2
    Δy = (grid.yf - grid.y0)/2
    poly = _make_bounding_box_polygon(FT, grid.xf, grid.xf + Δx, grid.y0 - Δy, grid.yf + Δy)
    return poly, grid.xf
end

"""
    West<:AbstractDirection


A simple subtype of [`AbstractDirection`](@ref) used for parametrically typing a subtype of
[`AbstractBoundary`](@ref) if that boundary is the western boundary in a rectangular domain.
"""
struct West<:AbstractDirection end


#=
    _grid_boundary_info(FT, West, grid)

Create a bounding box polygon representing the Western boundary of a rectangular grid with
points of float type `FT`. If the length of the grid x-extent is `Lx = xf - x0` then the
x-extent of the boundary polygon will range from `x0 - Lx/2` to `x0` in the x-direction.
If the length of the grid y-extent is `Ly = yf - y0` then the boundary polygon will range from
`y0 - Ly/2` to `yf + Ly/2` in the y-direction. This will create overlap with other boundary walls,
if all created from the grid, making sure all floes connect with boundaries at edges of
the domain.

Also return value `x0` as the value representing the edge of the boundary connecting with
the edge of the domain.
=#
function _grid_boundary_info(::Type{FT}, ::Type{West}, grid::RegRectilinearGrid) where FT
    Δx = (grid.xf - grid.x0)/2
    Δy = (grid.yf - grid.y0)/2
    poly = _make_bounding_box_polygon(FT, grid.x0 - Δx, grid.x0, grid.y0 - Δy, grid.yf + Δy)
    return poly, grid.x0
end

"""
    AbstractDomainElement{FT<:AbstractFloat}

An abstract type for all of the element that create the shape of the domain:
the 4 boundary walls that make up the rectangular domain and the topography
within the domain. 
"""
abstract type AbstractDomainElement{FT<:AbstractFloat} end


"""
    AbstractBoundary{D<:AbstractDirection, FT}<:AbstractDomainElement{FT}

An abstract type for the types of boundaries at the edges of the model domain.
Boundary types will control behavior of sea ice floes at edges of domain.
The direction given by type D denotes which edge of a domain this boundary could
be and type FT is the simulation float type (e.g. Float64 or Float32).

Each boundary type has the coordinates of the boudnary as a field. These should
be shapes that completely seal the domain, and should overlap on the corners as
seen in the example below:
 ________________
|__|____val___|__| <- North coordinates include corners
|  |          |  |
|  |          |  | <- East and west coordinates ALSO include corners
|  |          |  |
Each bounday type also has a field called "val" that holds value that defines
the line y = val or x = val (depending on boundary direction), such that if the
floe crosses that line it would be partially within the boundary. 
"""
abstract type AbstractBoundary{
    D<:AbstractDirection,
    FT,
}<:AbstractDomainElement{FT} end

"""
    OpenBoundary <: AbstractBoundary

A sub-type of AbstractBoundary that allows a floe to pass out of the domain edge
without any effects on the floe.
"""
struct OpenBoundary{D, FT}<:AbstractBoundary{D, FT}
    poly::BoundingBox{FT}
    val::FT
end

"""
    OpenBoundary(::Type{FT}, ::Type{D}, args...)

A float type FT can be provided as the first argument of any OpenBoundary
constructor. The second argument D is the directional type of the boundary.
An OpenBoundary of type FT and D will be created by passing all other arguments
to the correct constructor. 
"""
OpenBoundary(::Type{FT}, ::Type{D}, args...) where {
    FT <: AbstractFloat,
    D <: AbstractDirection,
} = OpenBoundary{D, FT}(args...)

"""
    OpenBoundary(::Type{D}, args...)

If a float type isn't specified, OpenBoundary will be of type Float64 and the
correct constructor will be called with all other arguments.
"""
OpenBoundary(::Type{D}, args...) where {D <: AbstractDirection} =
    OpenBoundary{D, Float64}(args...)

"""
    OpenBoundary{D, FT}(grid)

Creates open boundary on the edge of the grid, and with the direction as a type.
Edge is determined by direction.
Inputs:
    grid        <AbstractGrid> model grid
Outputs:
    Open Boundary on edge of grid given by direction and type. 
"""
function OpenBoundary{D, FT}(
    grid,
) where {D <: AbstractDirection, FT <: AbstractFloat}
    poly, val = _grid_boundary_info(FT, D, grid)
    OpenBoundary{D, FT}(poly, val)

end

"""
    PeriodicBoundary <: AbstractBoundary

A sub-type of AbstractBoundary that moves a floe from one side of the domain to
the opposite side of the domain when it crosses the boundary, bringing the floe
back into the domain.
"""
struct PeriodicBoundary{D, FT}<:AbstractBoundary{D, FT}
    poly::BoundingBox{FT}
    val::FT
end

"""
    PeriodicBoundary(::Type{FT}, ::Type{D}, args...)

A float type FT can be provided as the first argument of any PeriodicBoundary
constructor. The second argument D is the directional type of the boundary.
A PeriodicBoundary of type FT and D will be created by passing all other
arguments to the correct constructor. 
"""
PeriodicBoundary(::Type{FT}, ::Type{D}, args...) where {
    FT <: AbstractFloat,
    D <: AbstractDirection,
} = PeriodicBoundary{D, FT}(args...)

"""
    PeriodicBoundary(::Type{D}, args...)

If a float type isn't specified, PeriodicBoundary will be of type Float64 and
the correct constructor will be called with all other arguments.
"""
PeriodicBoundary(::Type{D}, args...) where {D <: AbstractDirection} =
    PeriodicBoundary{D, Float64}(args...)

"""
    PeriodicBoundary{D, FT}(grid)

Creates periodic boundary on the edge of the grid, and with the direction as a
type. Edge is determined by direction.
Inputs:
    grid        <AbstractGrid> model grid
Outputs:
    Periodic Boundary on edge of grid given by direction and type. 
"""
function PeriodicBoundary{D, FT}(
    grid,
) where {D <: AbstractDirection, FT <: AbstractFloat}
    poly, val = _grid_boundary_info(FT, D, grid)
    PeriodicBoundary{D, FT}(
        poly,
        val,
    )
end

"""
    CollisionBoundary <: AbstractBoundary

A sub-type of AbstractBoundary that stops a floe from exiting the domain by
having the floe collide with the boundary. The boundary acts as an immovable,
unbreakable ice floe in the collision. 
"""
struct CollisionBoundary{D, FT}<:AbstractBoundary{D, FT}
    poly::BoundingBox{FT}
    val::FT
end

"""
    CollisionBoundary(::Type{FT}, ::Type{D}, args...)

A float type FT can be provided as the first argument of any CollisionBoundary
constructor. The second argument D is the directional type of the boundary.
A CollisionBoundary of type FT and D will be created by passing all other
arguments to the correct constructor. 
"""
CollisionBoundary(::Type{FT}, ::Type{D}, args...) where {
    FT <: AbstractFloat,
    D <: AbstractDirection,
} = CollisionBoundary{D, FT}(args...)

"""
    CollisionBoundary(::Type{D}, args...)

If a float type isn't specified, CollisionBoundary will be of type Float64 and
the correct constructor will be called with all other arguments.
"""
CollisionBoundary(::Type{D}, args...) where {D <: AbstractDirection} =
    CollisionBoundary{D, Float64}(args...)


"""
    CollisionBoundary{D, FT}(grid)

Creates collision boundary on the edge of the grid, and with the direction as a
type. Edge is determined by direction.
Inputs:
    grid        <AbstractGrid> model grid
    direction   <AbstractDirection> direction of boundary wall
Outputs:
    Collision Boundary on edge of grid given by direction. 
"""
function CollisionBoundary{D, FT}(
    grid,
) where {D <: AbstractDirection, FT <: AbstractFloat}
    poly, val = _grid_boundary_info(FT, D, grid)
    CollisionBoundary{D, FT}(
        poly,
        val,
    )
end

"""
    MovingBoundary <: AbstractBoundary

A sub-type of AbstractBoundary that creates a floe along the boundary that moves
towards the center of the domain at the given velocity, compressing the ice
within the domain. This subtype is a mutable struct so that the coordinates and
val can be changed as the boundary moves. The u and v velocities are in [m/s].

Note that with a u-velocity, east and west walls move towards the center of the domain,
providing compressive stress, and with a v-velocity, the bounday creates a shear stress by
incorporating the velocity into friction calculations but doesn't actually move. This means
that the boundaries cannot move at an angle, distorting the shape of the domain regardless
the the combination of u and v velocities. The same, but opposite is true for the north
and south walls.
"""
mutable struct MovingBoundary{D, FT}<:AbstractBoundary{D, FT}
    poly::BoundingBox{FT}
    val::FT
    u::FT
    v::FT
end

"""
    MovingBoundary(::Type{FT}, ::Type{D}, args...)

A float type FT can be provided as the first argument of any MovingBoundary
constructor. The second argument D is the directional type of the boundary.
A MovingBoundary of type FT and D will be created by passing all other
arguments to the correct constructor. 
"""
MovingBoundary(::Type{FT}, ::Type{D}, args...) where {
    FT <: AbstractFloat,
    D <: AbstractDirection,
} = MovingBoundary{D, FT}(args...)

"""
    MovingBoundary(::Type{D}, args...)

If a float type isn't specified, MovingBoundary will be of type Float64 and
the correct constructor will be called with all other arguments.
"""
MovingBoundary(::Type{D}, args...) where {D <: AbstractDirection} =
    MovingBoundary{D, Float64}(args...)


"""
    MovingBoundary{D, FT}(grid, velocity)

Creates compression boundary on the edge of the grid, and with the direction as
a type.
Edge is determined by direction.
Inputs:
        grid        <AbstractGrid> model grid
        u    <AbstractFloat> u velocity of boundary
        v    <AbstractFloat> v velocity of boundary
Outputs:
    MovingBoundary on edge of grid given by direction. 
"""
function MovingBoundary{D, FT}(
    grid,
    u,
    v,
) where {D <: AbstractDirection, FT <: AbstractFloat}
    poly, val = _grid_boundary_info(FT, D, grid)
    MovingBoundary{D, FT}(
        poly,
        val,
        u,
        v,
    )
end

"""
    NonPeriodicBoundary

Union of all non-peridic boundary types to use as shorthand for dispatch.
"""
const NonPeriodicBoundary = Union{
    OpenBoundary,
    CollisionBoundary,
    MovingBoundary,
}

"""
    TopographyElement{FT}<:AbstractDomainElement{FT}

Singular topographic element with coordinates field storing where the element is
within the grid. These are used to create the desired topography within the
simulation and will be treated as islands or coastline within the model
in that they will not move or break due to floe interactions, but they will
affect floes.
"""
struct TopographyElement{FT}<:AbstractDomainElement{FT}
    poly::Polys{FT}
    coords::PolyVec{FT}
    centroid::Vector{FT}
    rmax::FT

    function TopographyElement{FT}(
        poly,
        coords,  # TODO: Can remove when not used anymore in other parts of the code
        centroid,
        rmax,
    ) where {FT <: AbstractFloat}
        if rmax <= 0
            throw(ArgumentError("Topography element maximum radius must be \
                positive and non-zero."))
        end
        poly = GO.ClosedRing()(poly)
        new{FT}(poly, find_poly_coords(poly), centroid, rmax)
    end
end

"""
    TopographyElement(::Type{FT}, args...)

A float type FT can be provided as the first argument of any TopographyElement
constructor. A TopographyElement of type FT will be created by passing all other
arguments to the correct constructor. 
"""
TopographyElement(::Type{FT}, args...) where {FT <: AbstractFloat} =
    TopographyElement{FT}(args...)

"""
    TopographyElement(args...)

If a type isn't specified, TopographyElement will be of type Float64 and the
correct constructor will be called with all other arguments.
"""
TopographyElement(args...) = TopographyElement{Float64}(args...)

"""
    TopographyElement{FT}(poly)

Constructor for topographic element with Polygon
Inputs:
    poly    <Polygon>
Output:
    Topographic element of abstract float type FT
"""
function TopographyElement{FT}(poly::Polys) where {FT <: AbstractFloat}
    rmholes!(poly)
    centroid = collect(GO.centroid(poly)) # TODO: Remove collect once type is changed
    coords = find_poly_coords(poly)
    rmax = calc_max_radius(poly, centroid, FT)
    return TopographyElement{FT}(
        poly,
        coords,
        centroid,
        rmax,
    )
end

"""
    TopographyElement{FT}(coords)

Constructor for topographic element with PolyVec coordinates
Inputs:
    coords      <PolyVec>
Output:
    Topographic element of abstract float type FT
"""
TopographyElement{FT}(coords::PolyVec) where {FT <: AbstractFloat} =
    TopographyElement{FT}(make_polygon(convert(PolyVec{FT}, coords)))

"""
    initialize_topography_field(args...)

If a type isn't specified, the list of TopographyElements will each be of type
Float64 and the correct constructor will be called with all other arguments.
"""
initialize_topography_field(args...) =
    initialize_topography_field(Float64, args...)

"""
    initialize_topography_field(
        ::Type{FT},
        coords,
    )

Create a field of topography from a list of polygon coordiantes.
Inputs:
    Type{FT}        <AbstractFloat> Type for grid's numberical fields -
                        determines simulation run type
    coords          <Vector{PolyVec}> list of polygon coords to make into floes
Outputs:
    topo_arr <StructArray{TopographyElement}> list of topography elements
    created from given polygon coordinates
"""
function initialize_topography_field(
    ::Type{FT},
    coords,
) where {FT <: AbstractFloat}
    topo_multipoly = GO.DiffIntersectingPolygons()(GI.MultiPolygon(coords))
    topo_arr = StructArray{TopographyElement{FT}}(undef, GI.npolygon(topo_multipoly))
    for (i, p) in enumerate(GI.getpolygon(topo_multipoly))
        topo_arr[i] = TopographyElement{FT}(p)
    end
    return topo_arr
end

"""
    periodic_compat(b1, b2)

Checks if two boundaries are compatible as a periodic pair. This is true if they
are both periodic, or if neither are periodic. Otherwise, it is false. 
"""
function periodic_compat(::PeriodicBoundary, ::PeriodicBoundary)
    return true
end

function periodic_compat(::PeriodicBoundary, _)
    return false
end

function periodic_compat(_, ::PeriodicBoundary)
    return false
end

function periodic_compat(_, _)
    return true
end

"""
Domain that holds 4 Boundary elements, forming a rectangle bounding the model
during the simulation, and a list of topography elements.

In order to create a Domain, three conditions need to be met. First, if needs to
be periodically compatible. This means that pairs of opposite boundaries both
need to be periodic if one of them is periodic. Next, the value in the north
boundary must be greater than the south boundary and the value in the east
boundary must be greater than the west in order to form a valid rectangle.

Note: The code depends on the boundaries forming a rectangle oriented along the
cartesian grid. Other shapes/orientations are not supported at this time. 
"""
struct Domain{
    FT<:AbstractFloat,
    NB<:AbstractBoundary{North, FT},
    SB<:AbstractBoundary{South, FT},
    EB<:AbstractBoundary{East, FT},
    WB<:AbstractBoundary{West, FT},
    TT<:StructArray{<:TopographyElement{FT}},
}
    north::NB
    south::SB
    east::EB
    west::WB
    topography::TT

    function Domain{FT, NB, SB, EB, WB, TT}(
        north::NB,
        south::SB,
        east::EB,
        west::WB,
        topography::TT,
    ) where {
        FT<:AbstractFloat,
        NB<:AbstractBoundary{North, FT},
        SB<:AbstractBoundary{South, FT},
        EB<:AbstractBoundary{East, FT},
        WB<:AbstractBoundary{West, FT},
        TT<:StructArray{<:TopographyElement{FT}},
    }
        if !periodic_compat(north, south)
            throw(ArgumentError("North and south boundary walls are not \
                periodically compatable as only one of them is periodic."))
        elseif !periodic_compat(east, west)
            throw(ArgumentError("East and west boundary walls are not \
                periodically compatable as only one of them is periodic."))
        elseif north.val < south.val
            throw(ArgumentError("North boundary value is less than south \
                boundary value."))
        elseif east.val < west.val
            throw(ArgumentError("East boundary value is less than west \
                boundary value."))
        end
        new{FT, NB, SB, EB, WB, TT}(north, south, east, west, topography)
    end

    Domain(
        north::NB,
        south::SB,
        east::EB,
        west::WB,
        topography::TT,
    ) where {
        FT<:AbstractFloat,
        NB<:AbstractBoundary{North, FT},
        SB<:AbstractBoundary{South, FT},
        EB<:AbstractBoundary{East, FT},
        WB<:AbstractBoundary{West, FT},
        TT<:StructArray{<:TopographyElement{FT}},
    } =
        Domain{FT, NB, SB, EB, WB, TT}(north, south, east, west, topography)
end

function get_domain_element(domain, idx)
    if idx == -1
        return domain.north
    elseif idx == -2
        return domain.south
    elseif idx == -3
        return domain.east
    elseif idx == -4
        return domain.west
    else
        topo_idx = -(idx + 4)
        return get_floe(domain.topography, topo_idx)
    end
end

"""
    Domain(north, south, east, west)

Creates domain with empty list of topography and given boundaries.
Inputs:
    north   <AbstractBoundary> north boundary
    south   <AbstractBoundary> south boundary
    east    <AbstractBoundary> east boundary
    west    <AbstractBoundary> west boundary
"""
Domain(
    north::NB,
    south::SB,
    east::EB,
    west::WB,
) where {
    FT<:AbstractFloat,
    NB<:AbstractBoundary{North, FT},
    SB<:AbstractBoundary{South, FT},
    EB<:AbstractBoundary{East, FT},
    WB<:AbstractBoundary{West, FT},
} =
    Domain(
        north,
        south,
        east,
        west,
        StructArray{TopographyElement{FT}}(undef, 0),
    )
