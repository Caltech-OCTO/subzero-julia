"""
Structs and functions used to define a Subzero model
"""

"""
    Grid{FT<:AbstractFloat}

Grid splitting the model into distinct rectanglular grid cells where xg are the grid lines in the x-direction (1xn vector)
and yg are the grid lines in the y-direction (mx1 vector). xc and cy are the mid-lines on grid cells in the x and y-direction.
These have dimensions n-1x1 and m-1x1 respectively. The dimension field holds the number of rows (m-1) and columns (n-1) in the grid.
The dimensions of each of the fields must match according to the above definitions.

This struct is also used to create a coarse grid of the model domain.
Ocean and floe data is averaged over this coarse grid and then saved as model output.
"""
struct Grid{FT<:AbstractFloat}
    dims::Tuple{Int, Int}
    xg::Vector{FT}
    yg::Vector{FT}
    xc::Vector{FT}
    yc::Vector{FT}

    Grid(dims, xg, yg, xc, yc) =
        (length(xg) == dims[2]+1 && length(yg) == dims[1]+1 &&
        length(xc) == dims[2] && length(yc) == dims[1]) ?
        new{eltype(xg)}(dims, xg, yg, xc, yc) :
        throw(ArgumentError("Dimension field doesn't match grid dimensions."))
end

"""
    Grid(lx, ux, ly, uy, Δx, Δy, t::Type{T} = Float64)

Construct a rectanglular grid for model given upper and lower bounds for x and y and grid cell dimensions.
Inputs: 
        lx       <Real> lower bound of grid x-direction
        ux       <Real> upper bound of grid x-direction
        ly       <Real> lower bound of grid y-direction
        uy       <Real> upper bound of grid y-direction
        Δx       <Real> length/height of grid cells in x-direction
        Δy       <Real> length/height of grid cells in y-direction
        t        <Type> datatype to convert grid fields - must be a Float!
Output: 
        Grid from lx to ux and height from ly to uy with grid squares of size Δx by Δy
Warning: If Δx doesn't evenly divide x length (lu-lx) or Δy doesn't evenly 
         divide y length (uy-ly) you won't get full size grid. The grid will be "trimmed" to the nearest
         full grid square in both directions.
"""
function Grid(lx, ux, ly, uy, Δx, Δy, t::Type{T} = Float64) where T
    xg = collect(T, lx:Δx:ux) 
    yg = collect(T, ly:Δy:uy)
    nx = length(xg) - 1
    ny = length(yg) - 1
    xc = collect(xg[1]+Δx/2:Δx:xg[end]-Δx/2)
    yc = collect(yg[1]+Δy/2:Δy:yg[end]-Δy/2)
    return Grid((ny, nx), xg, yg, xc, yc)
end


"""
    Grid(Lx, Ly, Δx, Δy, t::Type{T} = Float64)

Construct a rectanglular grid for the model given Lx, Ly and cell dimensions.
Inputs: 
        Lx       <Real> grid length will range from 0 to Lx
        Ly       <Real> grid height will range from y to Ly
        Δx       <Real> length/height of grid cells in x-direction
        Δy       <Real> length/height of grid cells in y-direction
        t        <Type> datatype to convert grid fields - must be a Float!
Output: 
        Grid with length of Lx (0.0 to LX) and height of Ly (0.0 to LY) with square Δx by Δy grid cells
Warning: If Δx doesn't evenly divide Lx or Δy doesn't evenly divide Ly you 
         won't get full size grid. The grid will be "trimmed" to the nearest full grid square.
"""
function Grid(Lx, Ly, Δx, Δy, t::Type{T} = Float64) where T
    return Grid(0.0, Lx, 0.0, Ly, Δx, Δy, T)
end

"""
    Grid(Lx, Ly, Δx, Δy, t::Type{T} = Float64)

Construct a rectanglular grid for model given upper and lower bounds for x and y and the number of grid cells
in both the x and y direction.
Inputs: 
        lx       <Real> lower bound of grid x-direction
        ux       <Real> upper bound of grid x-direction
        ly       <Real> lower bound of grid y-direction
        uy       <Real> upper bound of grid y-direction
        dims     <(Int, Int)> grid dimensions - rows -> ny, cols -> nx
        t        <Type> datatype to convert grid fields - must be a Float!
Output: 
        Grid from lx to ux and height from ly to uy with nx grid cells in the x-direction and ny grid cells in the y-direction.
"""
function Grid(lx, ux, ly, uy, dims::Tuple{Int, Int}, t::Type{T} = Float64) where T
    Δx = (ux-lx)/dims[2]
    Δy = (uy-ly)/dims[1]
    return Grid(lx, ux, ly, uy, Δx, Δy, T)
end

"""
    Grid(Lx, Ly, nx, ny, t::Type{T} = Float64)

    Construct a rectanglular grid for the model given Lx, Ly, and the number of grid cells in both the x and y direction.
Inputs: 
        Lx       <Real> grid length will range from 0 to Lx
        Ly       <Real> grid height will range from y to Ly
        dims     <(Int, Int)> grid dimensions
        t        <Type> datatype to convert grid fields - must be a Float!
Output: 
        Grid from 0 to Lx and height from 0 to Ly with nx grid cells in the x-direction and ny grid cells in the y-direction.
"""
function Grid(Lx, Ly, dims::Tuple{Int, Int}, t::Type{T} = Float64) where T
    Δx = Lx/dims[2]
    Δy = Ly/dims[1]
    return Grid(0.0, Lx, 0.0, Ly, Δx, Δy, T)
end

"""
Ocean velocities in the x-direction (u) and y-direction (v). u and v should match the size of the corresponding
model grid so that there is one x and y velocity value for each grid cell. Ocean also needs temperature at the
ocean/ice interface in each grid cell. Ocean fields must all be matricies with the same dimensions.
Model cannot be constructed if size of ocean and grid do not match.
"""
struct Ocean{FT<:AbstractFloat}
    u::Matrix{FT}
    v::Matrix{FT}
    temp::Matrix{FT}
    τx::Matrix{FT}
    τy::Matrix{FT}
    si_frac::Matrix{FT}

    Ocean(u, v, temp, τx, τy, si_frac) =
        (size(u) == size(v) == size(temp) == size(τx) == size(τy) ==
         size(si_frac)) ?
        new{eltype(u)}(u, v, temp, τx, τy, si_frac) :
        throw(ArgumentError("All ocean fields matricies must have the same dimensions."))
end

"""
    Ocean(grid, u, v, temp, FT)

Construct model ocean.
Inputs: 
        grid    <Grid> model grid cell
        u       <Real> ocean x-velocity for each grid cell
        v       <Real> ocean y-velocity for each grid cell
        temp    <Real> temperature at ocean/ice interface per grid cell
        t       <Type> datatype to convert ocean fields - must be a Float!
Output: 
        Ocean with constant velocity and temperature in each grid cell.
"""
Ocean(grid::Grid, u, v, temp, t::Type{T} = Float64) where T =
    Ocean(fill(convert(T, u), grid.dims), 
          fill(convert(T, v), grid.dims), 
          fill(convert(T, temp), grid.dims),
          zeros(T, grid.dims), zeros(T, grid.dims), zeros(T, grid.dims))

# TODO: Do we want to be able to use a psi function? - Ask Mukund

"""
Wind velocities in the x-direction (u) and y-direction (v). u and v should match the size of the corresponding
model grid so that there is one x and y velocity value for each grid cell. Wind also needs temperature at the
atmosphere/ice interface in each grid cell. Model cannot be constructed if size of wind and grid do not match.
"""
struct Wind{FT<:AbstractFloat}
    u::Matrix{FT}
    v::Matrix{FT}
    temp::Matrix{FT}

    Wind(u, v, temp) =
    (size(u) == size(v) == size(temp)) ?
    new{eltype(u)}(u, v, temp) :
    throw(ArgumentError("All wind fields matricies must have the same dimensions."))
end

"""
    Wind(grid, u, v, FT)

Construct model atmosphere/wind.
Inputs: 
        grid    <Grid> model grid cell
        u       <Real> wind x-velocity for each grid cell
        v       <Real> wind y-velocity for each grid cell
        temp    <Real> temperature at atmopshere/ice interface per grid cell
        t       <Type> datatype to convert ocean fields - must be a Float!
Output: 
        Ocean with constant velocity and temperature in each grid cell.
"""
Wind(grid, u, v, temp, t::Type{T} = Float64) where T = 
    Wind(fill(convert(T, u), grid.dims),
         fill(convert(T, v), grid.dims),
         fill(convert(T, temp), grid.dims))


abstract type AbstractDirection end

struct North<:AbstractDirection end

struct South<:AbstractDirection end

struct East<:AbstractDirection end

struct West<:AbstractDirection end

function boundary_coords(grid::Grid, ::North)
    Δx = (grid.xg[end] - grid.xg[1])/2 # Half of the grid in x
    Δy = (grid.yg[end] - grid.yg[1])/2 # Half of the grid in y
    return grid.yg[end],  # val
        [[[grid.xg[1] - Δx, grid.yg[end]],  # coords
          [grid.xg[1] - Δx, grid.yg[end] + Δy],
          [grid.xg[end] + Δx, grid.yg[end] + Δy], 
          [grid.xg[end] + Δx, grid.yg[end]], 
          [grid.xg[1] - Δx, grid.yg[end]]]]
end

function boundary_coords(grid::Grid, ::South)
    Δx = (grid.xg[end] - grid.xg[1])/2 # Half of the grid in x
    Δy = (grid.yg[end] - grid.yg[1])/2 # Half of the grid in y
    return grid.yg[1],  # val
        [[[grid.xg[1] - Δx, grid.yg[1] - Δy],  # coords
          [grid.xg[1] - Δx, grid.yg[1]],
          [grid.xg[end] + Δx, grid.yg[1]], 
          [grid.xg[end] + Δx, grid.yg[1] - Δy], 
          [grid.xg[1] - Δx, grid.yg[1] - Δy]]]
end

function boundary_coords(grid::Grid, ::East)
    Δx = (grid.xg[end] - grid.xg[1])/2 # Half of the grid in x
    Δy = (grid.yg[end] - grid.yg[1])/2 # Half of the grid in y
    return grid.xg[end],  # val
        [[[grid.xg[end], grid.yg[1] - Δy],  # coords
          [grid.xg[end], grid.yg[end] + Δy],
          [grid.xg[end] + Δx, grid.yg[end] + Δy], 
          [grid.xg[end] + Δx, grid.yg[1] - Δy], 
          [grid.xg[end], grid.yg[1] - Δy]]]
end

function boundary_coords(grid::Grid, ::West)
    Δx = (grid.xg[end] - grid.xg[1])/2 # Half of the grid in x
    Δy = (grid.yg[end] - grid.yg[1])/2 # Half of the grid in y
    return grid.xg[1],  # val
        [[[grid.xg[1] - Δx, grid.yg[1] - Δy],  # coords
          [grid.xg[1] - Δx, grid.yg[end] + Δy],
          [grid.xg[1], grid.yg[end] + Δy], 
          [grid.xg[1], grid.yg[1] - Δy], 
          [grid.xg[1] - Δx, grid.yg[1] - Δy]]]
end
"""
    AbstractBoundary{FT<:AbstractFloat}

An abstract type for the types of boundaries at the edges of the model domain.
Boundary conditions will control behavior of sea ice floes at edges of domain.

Note that the boundary coordinates must include the corner of the boundary as can be seen in the diagram below.
 ________________
|__|____val___|__| <- North coordinates must include corners
|  |          |  |
|  |          |  | <- East coordinates must ALSO include corners
|  |          |  |
Val field holds value that defines the line y = val such that if the floe crosses that line it would be
partially within the boundary. 
"""
abstract type AbstractBoundary{D<:AbstractDirection, FT<:AbstractFloat} end

"""
    OpenBoundary <: AbstractBoundary

A simple concrete type of boundary, which allows a floe to pass out of the domain edge without any effects on the floe.
"""
struct OpenBoundary{D, FT}<:AbstractBoundary{D, FT}
    coords::PolyVec{FT}
    val::FT
end

function OpenBoundary(coords, val, direction::AbstractDirection)
    return OpenBoundary{typeof(direction), typeof(val)}(coords, val)
end

function OpenBoundary(grid::Grid, direction)
    val, coords = boundary_coords(grid, direction)
    OpenBoundary(coords, val, direction)
end

"""
    PeriodicBoundary <: AbstractBoundary

A simple concrete type of boundary, which moves a floe from one side of the domain to the opposite
side of the domain, bringing the floe back into the grid.

NOTE: Not implemented yet!
"""
struct PeriodicBoundary{D, FT}<:AbstractBoundary{D, FT}
    coords::PolyVec{FT}
    val::FT
end

function PeriodicBoundary(coords, val, direction::AbstractDirection)
    return PeriodicBoundary{typeof(direction), typeof(val)}(coords, val)
end

function PeriodicBoundary(grid::Grid, direction)
    val, coords = boundary_coords(grid, direction)
    PeriodicBoundary(coords, val, direction)
end

"""
    CollisionBoundary <: AbstractBoundary

A simple concrete type of boundary, which stops a floe from exiting the domain by having the floe collide with the boundary.
"""
struct CollisionBoundary{D, FT}<:AbstractBoundary{D, FT}
    coords::PolyVec{FT}
    val::FT
end

function CollisionBoundary(coords, val, direction::AbstractDirection)
    return CollisionBoundary{typeof(direction), typeof(val)}(coords, val)
end

function CollisionBoundary(grid::Grid, direction)
    val, coords = boundary_coords(grid, direction)
    CollisionBoundary(coords, val, direction)
end
"""
    CompressionBC <: AbstractBC

A simple concrete type of boundary, which creates a floe along the boundary that moves from the boundary towards
the center of the domain as the given velocity, compressing the ice within the dominan.

NOTE: Not implemented yet!
"""
mutable struct CompressionBoundary{D, FT}<:AbstractBoundary{D, FT}
    coords::PolyVec{FT}
    val::FT
    velocity::FT
end

function CompressionBoundary(coords, val, velocity, direction::AbstractDirection)
    return CompressionBoundary{typeof(direction), typeof(val)}(coords, val, velocity)
end

function CompressionBoundary(grid::Grid, direction)
    val, coords = boundary_coords(grid, direction)
    CompressionBoundary(coords, val, direction)
end
"""
    periodic_compat(b1::B, b2::B)

Checks if two boundaries with the same boundary condition B are compatible as opposites.
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
Domain that holds 4 Boundary elements, forming a rectangle bounding the model during the simulation. 

In order to create a Domain, three conditions need to be met. First, if needs to be periodically compatible.
This means that pairs of opposite boundaries both need to be periodic if one of them is periodic.
Next, the value in the north boundary must be greater than the south boundary and the value in the east boundary
must be greater than the west in order to form a valid rectangle.
"""
struct Domain{FT<:AbstractFloat, NB<:AbstractBoundary{North, FT}, SB<:AbstractBoundary{South, FT},
EB<:AbstractBoundary{East, FT}, WB<:AbstractBoundary{West, FT}}
    north::NB
    south::SB
    east::EB
    west::WB

    Domain(north, south, east, west) = 
        (periodic_compat(north, south) && periodic_compat(east, west)) &&
        (north.val > south.val && east.val > west.val) ?
        new{typeof(north.val), typeof(north), typeof(south), typeof(east), typeof(west)}(north, south, east, west) : 
        throw(ArgumentError("Periodic boundary must have matching opposite boundary and/or North value must be greater then South and East must be greater than West."))
end

"""
    Topography{FT<:AbstractFloat}

Singular topographic element with fields describing current state.
These are used to create the desired topography within the simulation and will be treated as "islands" within the model
in that they will not move or break due to floe interactions, but they will affect floes. 

Coordinates are vector of vector of vector of points of the form:
[[[x1, y1], [x2, y2], ..., [xn, yn], [x1, y1]], 
 [[w1, z1], [w2, z2], ..., [wn, zn], [w1, z1]], ...] where the xy coordinates are the exterior border of the element
 and the wz coordinates, or any other following sets of coordinates, describe holes within it - although there should not be any.
 This format makes for easy conversion to and from LibGEOS Polygons. 
"""
struct Topography{FT<:AbstractFloat}
    centroid::Vector{FT}
    coords::PolyVec{FT}     # coordinates of topographical element
    height::FT              # height (m)
    area::FT                # area (m^2)
    rmax::FT                # distance of vertix farthest from centroid (m)

    Topography(centroid, coords, height, area, rmax) = 
        height > 0 && area > 0 && rmax > 0 ?
        new{typeof(height)}(centroid, coords, height, area, rmax) :
        throw(ArgumentError("Height, area, and maximum radius of a given topography element should be positive."))
end

"""
    Topography(poly::LG.Polygon, h, t::Type{T} = Float64)

Constructor for topographic element with LibGEOS Polygon
    Inputs:
            poly    <LibGEOS.Polygon> 
            h       <Real> height of element
            t       <Type> datatype to convert ocean fields - must be a Float!
    Output:
            Topographic element with needed fields defined
    Note:
            Types are specified at Float64 below as type annotations given that when written LibGEOS could exclusivley use Float64 (as of 09/29/22). When this is fixed, this annotation will need to be updated.
            We should only run the model with Float64 right now or else we will be converting the Polygon back and forth all of the time. 
"""
function Topography(poly::LG.Polygon, h, t::Type{T} = Float64) where T
    topo = rmholes(poly)
    centroid = LG.GeoInterface.coordinates(LG.centroid(topo))::Vector{Float64}
    area = LG.area(topo)::Float64 
    coords = LG.GeoInterface.coordinates(topo)::PolyVec{Float64}
    rmax = sqrt(maximum([sum(c.^2) for c in translate(coords, -centroid)[1]]))
    return Topography(convert(Vector{T}, centroid), convert(PolyVec{T}, coords),
                      convert(T, h), convert(T, area), convert(T, rmax))
end

"""
    Topography(coords::PolyVec{T}, h, t::Type{T} = Float64)

Topogrpahic element constructor with PolyVec{Float64}(i.e. Vector{Vector{Vector{Float64}}}) coordinates
Inputs:
poly    <LibGEOS.Polygon> 
h       <Real> height of element
t       <Type> datatype to convert ocean fields - must be a Float!
Output:
        Topographic element with needed fields defined
"""
function Topography(coords::PolyVec{<:Real}, h, t::Type{T} = Float64) where T
    return Topography(LG.Polygon(convert(PolyVec{Float64}, coords)), h, T)
    # Polygon convert is needed since LibGEOS only takes Float64 - when this is fixed convert can be removed
end

"""
Singular sea ice floe with fields describing current state. Centroid is a vector of points of the form: [x,y].
Coordinates are vector of vector of vector of points of the form:
[[[x1, y1], [x2, y2], ..., [xn, yn], [x1, y1]], 
 [[w1, z1], [w2, z2], ..., [wn, zn], [w1, z1]], ...] where the xy coordinates are the exterior border of the floe
and the wz coordinates, or any other following sets of coordinates, describe holes within the floe.
There should not be holes for the majority of the time as they will be removed, but this format makes for easy
conversion to and from LibGEOS Polygons. 
"""
@kwdef mutable struct Floe{FT<:AbstractFloat}
    centroid::Vector{FT}    # center of mass of floe (might not be in floe!)
    height::FT              # floe height (m)
    area::FT                # floe area (m^2)
    mass::FT                # floe mass (kg)
    moment::FT              # mass moment of intertia
    #angles::Vector{T}
    rmax::FT                # distance of vertix farthest from centroid (m)
    coords::PolyVec{FT}     # floe coordinates
    α::FT = 0.0             # floe rotation from starting position in radians
    u::FT = 0.0             # floe x-velocity
    v::FT = 0.0             # floe y-velocity
    ξ::FT = 0.0             # floe angular velocity
    fxOA::FT = 0.0          # force from ocean and wind in x direction
    fyOA::FT = 0.0          # force from ocean and wind in y direction
    torqueOA::FT = 0.0      # torque from ocean and wind
    p_dxdt::FT = 0.0        # previous timestep x-velocity
    p_dydt::FT = 0.0        # previous timestep y-velocity
    p_dudt::FT = 0.0        # previous timestep x-acceleration
    p_dvdt::FT = 0.0        # previous timestep x-acceleration
    p_dξdt::FT = 0.0        # previous timestep time derivative of ξ
    p_dαdt::FT = 0.0        # previous timestep ξ
    hflx::FT = 0.0          # heat flux under the floe
    overarea::FT = 0.0      # total overlap with other floes
    alive::Int = 1          # floe is still active in simulation
                            # floe interactions with other floes/boundaries
    interactions::NamedMatrix{FT} = NamedArray(zeros(7),
        (["floeidx", "xforce", "yforce", "xpoint", "ypoint", "torque", "overlap"]))'
    collision_force::Matrix{FT} = [0.0 0.0] 
    collision_torque::FT = 0.0
end # TODO: do we want to do any checks? Ask Mukund!

"""
    Floe(poly::LG.Polygon, hmean, Δh, ρi = 920.0, u = 0.0, v = 0.0, ξ = 0.0, t::Type{T} = Float64)

Constructor for floe with LibGEOS Polygon
Inputs:
        poly        <LibGEOS.Polygon> 
        h_mean      <Real> mean height for floes
        Δh          <Real> variability in height for floes
        ρi          <Real> ice density kg/m3 - default 920
        u           <Real> x-velocity of the floe - default 0.0
        v           <Real> y-velcoity of the floe - default 0.0
        ksi         <Real> angular velocity of the floe - default 0.0
        t           <Type> datatype to convert ocean fields - must be a Float!
Output:
        Floe with needed fields defined - all default field values used so all forcings start at 0 and floe is "alive".
        Velocities and the density of ice can be optionally set.
Note:
        Types are specified at Float64 below as type annotations given that when written LibGEOS could exclusivley use Float64 (as of 09/29/22).
        When this is fixed, this annotation will need to be updated.
        We should only run the model with Float64 right now or else we will be converting the Polygon back and forth all of the time. 
"""
function Floe(poly::LG.Polygon, hmean, Δh; ρi = 920.0, u = 0.0, v = 0.0, ξ = 0.0, t::Type{T} = Float64) where T
    floe = rmholes(poly)
    centroid = LG.GeoInterface.coordinates(LG.centroid(floe))::Vector{Float64}
    h = hmean + (-1)^rand(0:1) * rand() * Δh  # floe height
    area = LG.area(floe)::Float64  # floe area
    mass = area * h * ρi  # floe mass
    moment = calc_moment_inertia(floe, h, ρi = ρi)
    coords = LG.GeoInterface.coordinates(floe)::PolyVec{Float64}
    rmax = sqrt(maximum([sum(c.^2) for c in translate(coords, -centroid)[1]]))
    

    return Floe(centroid = convert(Vector{T}, centroid), height = convert(T, h), area = convert(T, area),
                mass = convert(T, mass), moment = convert(T, moment), coords = convert(PolyVec{T}, coords),
                rmax = convert(T, rmax), u = convert(T, u), v = convert(T, v), ξ = convert(T, ξ))
end

"""
    Floe(coords::PolyVec{Float64}, h_mean, Δh, ρi = 920.0, u = 0.0,
    v = 0.0, ξ = 0.0, t::Type{T} = Float64) where T

Floe constructor with PolyVec{Float64}(i.e. Vector{Vector{Vector{Float64}}}) coordinates
Inputs:
        coords      <Vector{Vector{Vector{Float64}}}> floe coordinates
        h_mean      <Real> mean height for floes
        h_delta     <Real> variability in height for floes
        rho_ice     <Real> ice density kg/m3
        u           <Real> x-velocity of the floe - default 0.0
        v           <Real> y-velcoity of the floe - default 0.0
        ksi         <Real> angular velocity of the floe - default 0.0
        t           <Type> datatype to convert ocean fields - must be a Float!
Output:
        Floe with needed fields defined - all default field values used so all forcings and velocities start at 0 and floe is "alive"
"""
Floe(coords::PolyVec{<:Real}, h_mean, Δh; ρi = 920.0, u = 0.0, v = 0.0, ξ = 0.0, t::Type{T} = Float64) where T =
    Floe(LG.Polygon(convert(PolyVec{Float64}, coords)), h_mean, Δh, ρi, u, v, ξ, T) 
    # Polygon convert is needed since LibGEOS only takes Float64 - when this is fixed convert can be removed

"""
    domain_in_grid(domain::Domain, grid)

Checks if given rectangular domain is within given grid and gives user a warning if domain is not of maximum possible size given grid dimensions.

Inputs:
        domain      <RectangularDomain>
        grid        <Grid>
Outputs:
        <Boolean> true if domain is within grid bounds, else false
"""
function domain_in_grid(domain::Domain, grid)
    northval = domain.north.val
    southval = domain.south.val
    eastval = domain.east.val
    westval = domain.west.val
    if (northval <= grid.yg[end] &&
        southval >= grid.yg[1] &&
        eastval <= grid.xg[end] &&
        westval >= grid.xg[1])
        if (northval != grid.yg[end] ||
            southval != grid.yg[1] ||
            eastval != grid.xg[end] ||
            westval != grid.xg[1])
            @warn "At least one wall of domain is smaller than grid. This could lead to unneeded computation. Consider making grid smaller or domain larger."
        end 
        return true
    end
    return false
end

@kwdef struct Constants{FT<:AbstractFloat}
    ρi::FT = 920.0              # Ice density
    ρo::FT = 1027.0             # Ocean density
    ρa::FT = 1.2                # Air density
    Cd_io::FT = 3e-3            # Ice-ocean drag coefficent
    Cd_ia::FT = 1e-3            # Ice-atmosphere drag coefficent
    Cd_ao::FT = 1.25e-3         # Atmosphere-ocean momentum drag coefficient
    f::FT = 1.4e-4              # Ocean coriolis parameter
    turnθ::FT = 15*pi/180       # Ocean turn angle
    L::FT = 2.93e5              # Latent heat of freezing [Joules/kg]
    k::FT = 2.14                # Thermal conductivity of surface ice[W/(m*K)]
    ν::FT = 0.3                 # Poisson's ratio
    μ::FT = 0.2                 # Coefficent of friction
    E::FT = 6e6                 # Young's Modulus
    #A::FT = 70.0                # upward flux constant A (W/m2)
    #B::FT = 10.0                # upward flux constant B (W/m2/K)
    #Q::FT = 200.0               # solar constant (W/m2)
    #αocn::FT = 0.4              # ocean albedo
end

"""
Model which holds grid, ocean, wind structs, each with the same underlying float type (either Float32 of Float64). It also holds an StructArray of floe structs, again each relying on the same underlying float type. Finally it holds several physical constants. These are:
- hflx: difference in ocean and atmosphere temperatures
- h_new: the height of new ice that forms during the simulation
- modulus: elastic modulus used in floe interaction calculations
- ρi: density of ice
- ρo: density of ocean water
- ρa: density of atmosphere
- Cd_io: ice-ocean drag coefficent
- Cd_ia: ice-atmosphere drag coefficent
- f: ocean coriolis forcings
- turn angle: Ekman spiral caused angle between the stress and surface current
              (angle is positive)
"""
struct Model{FT<:AbstractFloat, DT<:Domain{FT, <:AbstractBoundary, <:AbstractBoundary, <:AbstractBoundary, <:AbstractBoundary}}
    grid::Grid{FT}
    ocean::Ocean{FT}
    wind::Wind{FT}
    domain::DT
    topos::StructArray{Topography{FT}}
    floes::StructArray{Floe{FT}}
    consts::Constants{FT}
    hflx::Matrix{FT}            # ocean heat flux

    Model(grid, ocean, wind, domain, topos, floes, consts, hflx) =
        (grid.dims == size(ocean.u) == size(wind.u) && domain_in_grid(domain, grid)) ?
        new{typeof(consts.ρi), typeof(domain)}(grid, ocean, wind, domain, topos, floes, consts, hflx) :
        throw(ArgumentError("Size of grid does not match size of ocean and/or wind OR domain is not within grid."))
end

"""
    Model(grid, ocean, wind, domain, topos, floes, Δt::Int, newfloe_Δt::Int;
    ρi = 920.0, t::Type{T} = Float64)

Model constructor
Inputs:
        grid        <Grid>
        ocean       <Ocean>
        wind        <Wind>
        domain      <AbstractDomain subtype>
        topo        <StructArray{<:Topography}>
        floes       <StructArray{<:Floe}>
        consts      <Contants>
        t           <Type> datatype to convert ocean fields - must
                           be a Float! 
Outputs:
        Model with all needed fields defined and converted to type t.        
"""
function Model(grid, ocean, wind, domain, topos, floes, consts, t::Type{T} = Float64) where T
    hflx = consts.k/(consts.ρi*consts.L) .* (wind.temp .- ocean.temp)
    return Model(grid, ocean, wind, domain, topos, floes, consts,
                 convert(Matrix{T}, hflx))
end
