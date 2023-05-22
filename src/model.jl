"""
Structs and functions used to define a Subzero model
"""

"""
    CellFloes{FT<:AbstractFloat}

Struct that tracks which floes are within given cell, as well as the translation
vector needed to move floe each from current postion into cell if it is in cell
due to periodic boundaries. Each index in floeidx is the index of a floe within
the cell and the Δx and Δy with the same index are that floe's translation
vector.
Note: the floeidx is the index of grid cells centered on grid lines, not on the
grid cells defined by the regular, rectilinear grid. 
"""
struct CellFloes{FT<:AbstractFloat}
    floeidx::Vector{Int}
    Δx::Vector{FT}
    Δy::Vector{FT}
end

"""
    CellFloes{FT}()

Constructs an CellFloes object with empty lists for fields.
"""
CellFloes{FT}() where {FT} = CellFloes{FT}(
    Vector{Int}(),
    Vector{FT}(),
    Vector{FT}()
)
"""
    empty!(cell::CellFloes)

Empties the vectors within a CellFloes object
"""
function Base.empty!(cell::CellFloes)
    empty!(cell.floeidx)
    empty!(cell.Δx)
    empty!(cell.Δy)
    return
end

"""
    AbstractGrid

An abstract type for the grid that model will be simulated on.
Affects calculation on the grid.
"""
abstract type AbstractGrid{FT<:AbstractFloat} end

"""
    RegRectilinearGrid{FT<:AbstractFloat}<:AbstractGrid

Tessellation of 2-dimensional Euclidean space into n-by-m congruent rectangles.
The dimension of grid is n rows by m columns, and the struct hold the grid-line
and grid-center values:
 - xg are the grid lines in the x-direction (m+1 length vector)
 - yg are the grid lines in the y-direction (n+1 length vector)
 - xc are the mid-lines on grid cells (m length vector) in the x-direction
 - yc are the mid-lines on grid cells (n length vector) in the y-direction
The dimensions of each of the fields must match according to above definitions.
"""
struct RegRectilinearGrid{FT}<:AbstractGrid{FT}
    dims::Tuple{Int, Int}
    xg::Vector{FT}
    yg::Vector{FT}
    xc::Vector{FT}
    yc::Vector{FT}
    floe_locations::Matrix{CellFloes{FT}}

    function RegRectilinearGrid{FT}(
        dims,
        xg::Vector{FT},
        yg::Vector{FT},
        xc::Vector{FT},
        yc::Vector{FT},
        floe_locations::Matrix{CellFloes{FT}},
    ) where {FT <: AbstractFloat}
        if (length(xg) != dims[2]+1) || (length(yg) != dims[1]+1)
            throw(ArgumentError("Grid line dimensions vector doesn't match \
                dimensions field."))
        end
        if (length(xc) != dims[2]) || (length(yc) != dims[1])
            throw(ArgumentError("Grid center dimensions vector doesn't match \
                dimensions field."))
        end

        new{FT}(dims, xg, yg, xc, yc, floe_locations)
    end

    RegRectilinearGrid(
        dims,
        xg::Vector{FT},
        yg::Vector{FT},
        xc::Vector{FT},
        yc::Vector{FT},
        floe_locations::Matrix{CellFloes{FT}},
    ) where {FT <: AbstractFloat} = 
        RegRectilinearGrid{FT}(dims, xg, yg, xc, yc, floe_locations)
end

"""
    RegRectilinearGrid(
        ::Type{FT};
        xbounds::Tuple,
        ybounds::Tuple,
        Δx,
        Δy,
    )

Construct a RegRectilinearGrid for model given bounds for grid x and y and grid
cell dimensions.
Inputs:
    Type{FT} <AbstractFloat> Type for grid's numberical fields - determines
                simulation run type
    xbounds  <Tuple{Real, Real}> bound of grid x-direction in form (left, right)
    ybounds  <Tuple{Real, Real}> bound of grid y-direction in form (bottom, top)
    Δx       <Real> length/height of grid cells in x-direction
    Δy       <Real> length/height of grid cells in y-direction
Output: 
    RegRectilinearGrid from lx to ux and height from ly to uy with grid squares
    of size Δx by Δy
Warning:
    If Δx doesn't evenly divide x length (lu-lx) or Δy doesn't evenly divide y
    length (uy-ly) you won't get full size grid. The grid will be "trimmed" to
    the nearest full grid square in both directions.
"""
function RegRectilinearGrid(
    ::Type{FT},
    xbounds::Tuple,
    ybounds::Tuple,
    Δx,
    Δy,
) where {FT <: AbstractFloat}
    xg = collect(FT, xbounds[1]:Δx:xbounds[2]) 
    yg = collect(FT, ybounds[1]:Δy:ybounds[2])
    nx = length(xg) - 1
    ny = length(yg) - 1
    xc = collect(FT, xg[1]+Δx/2:Δx:xg[end]-Δx/2)
    yc = collect(FT, yg[1]+Δy/2:Δy:yg[end]-Δy/2)
    locations = [CellFloes{FT}() for i in 1:(ny + 1), j in 1:(nx + 1)]
    return RegRectilinearGrid((ny, nx), xg, yg, xc, yc, locations)
end

"""
    RegRectilinearGrid(
        ::Type{FT};
        xbounds::Tuple{Real, Real},
        ybounds::Tuple{Real, Real},
        dims::Tuple{Int, Int}
    )

Construct a RegRectilinearGrid for model given bounds for grid x and y and the
number of grid cells in both the x and y direction.
Inputs: 
    Type{FT} <AbstractFloat> Type for grid's numberical fields - determines
                simulation run type
    xbounds  <Tuple{Real, Real}> bound of grid x-direction in form (left, right)
    ybounds  <Tuple{Real, Real}> bound of grid y-direction in form (bottom, top)
    dims     <(Int, Int)> grid dimensions given as (rows, columns) where rows is
                the number of y cells and columns is the number of x cells
Output: 
    RegRectilinearGrid with width and height determined by xbound and ybounds
    and the number of grid cells in the x-direction and y-direction determined
    by dims.
"""
function RegRectilinearGrid(
    ::Type{FT},
    xbounds::Tuple,
    ybounds::Tuple,
    dims::Tuple{Int, Int},
) where {FT <: AbstractFloat}
    Δx = (xbounds[2] - xbounds[1])/dims[2]
    Δy = (ybounds[2] - ybounds[1])/dims[1]
    return RegRectilinearGrid(
        FT,
        xbounds,
        ybounds,
        Δx,
        Δy,
    )
end

"""
    IceStressCell{FT<:AbstractFloat}

Struct to collect stress from ice floes on ocean grid cells. One IceStressCell
corresponds to one grid cell. It holds a list of running totals of stress on the
cell, and a running list of the number of points making up those running totals.
Each element in the list corresponds to one floe, which is denoted in the
corresponding CellFloes matrix within the grid. 
"""
struct IceStressCell{FT<:AbstractFloat}
    τx::Vector{FT}
    τy::Vector{FT}
    npoints::Vector{Int}
end

"""
    IceStressCell{FT}()

Constructs an IceStressCell object with empty lists for fields.
"""
IceStressCell{FT}() where {FT} = IceStressCell{FT}(
    Vector{FT}(),
    Vector{FT}(),
    Vector{Int}()
)
"""
    empty!(cell::IceStressCell)

Empties the vectors within an IceStressCell
"""
function Base.empty!(cell::IceStressCell)
    empty!(cell.τx)
    empty!(cell.τy)
    empty!(cell.npoints)
    return
end

"""
    Ocean{FT<:AbstractFloat}

Simulation ocean holding ocean values on the grid-scale with matricies of the
same size as the model's grid. The struct has the following fields:
- u is the ocean velocities in the x-direction for each grid cell
- v is the ocean velocities in the y-direction for each grid cell
- temp is the ocean temperature for each grid cell
- hflx_factor is a factor to calculate the ocean-atmosphere heat flux for a 
  cell in that grid cell by multiplying by its height
- si_frac is the fraction of area in each grid cell that is covered in sea-ice

Ocean fields must all be matricies with dimensions equal to the number of grid
lines in the model's grid. 
Note: If a periodic boundary is used in the domain, the last grid cell in that
direction will not be used as it is equivalent to the first grid cell. Thus, for
all of these fields, the first and last value in the x and/or y direction should
be equal if the east-west or north-south boundary pair are periodic
respectively.
"""
struct Ocean{FT<:AbstractFloat}
    u::Matrix{FT}
    v::Matrix{FT}
    temp::Matrix{FT}
    hflx_factor::Matrix{FT}
    scells::Matrix{IceStressCell{FT}}
    τx::Matrix{FT}
    τy::Matrix{FT}
    si_frac::Matrix{FT}
    dissolved::Matrix{FT}

    function Ocean{FT}(
        u::Matrix{FT},
        v::Matrix{FT},
        temp::Matrix{FT},
        hflx::Matrix{FT},
        scells::Matrix{IceStressCell{FT}},
        τx::Matrix{FT},
        τy::Matrix{FT},
        si_frac::Matrix{FT},
        dissolved::Matrix{FT},
    ) where {FT <: AbstractFloat}
        if !all(-3 .<= temp .<= 0)
            @warn "Ocean temperatures are above the range for freezing. The \
                thermodynamics aren't currently setup for these conditions."
        end
        new{FT}(u, v, temp, hflx, scells, τx, τy, si_frac, dissolved)
    end

    Ocean(
        u::Matrix{FT},
        v::Matrix{FT},
        temp::Matrix{FT},
        hflx::Matrix{FT},
        scells::Matrix{IceStressCell{FT}},
        τx::Matrix{FT},
        τy::Matrix{FT},
        si_frac::Matrix{FT},
        dissolved::Matrix{FT},
    ) where {FT<:AbstractFloat} =
        Ocean{FT}(
            u,
            v,
            temp,
            hflx,
            scells,
            τx,
            τy,
            si_frac,
            dissolved,
        )
end

"""
    Ocean(::Type{T}, u, v, temp)

Construct model ocean.
Inputs:
    Type{FT} <AbstractFloat> Type for grid's numberical fields - determines
            simulation run type
    u       <Matrix> ocean x-velocity matrix with u for each grid line
    v       <Matrix> ocean y-velocity matrix with u for each grid line
    temp    <Matrix> temperature matrix with ocean/ice interface temperature for each grid line
Output: 
    Model ocean with given velocity and temperature fields on each grid line.
"""
function Ocean(
    ::Type{FT},
    u,
    v,
    temp,
) where {FT <: AbstractFloat}
    nvals = size(u)
    return Ocean(
        convert(Matrix{FT}, u),
        convert(Matrix{FT}, v),
        convert(Matrix{FT}, temp),
        zeros(FT, nvals),
        [IceStressCell{FT}() for i in 1:nvals[1], j in 1:nvals[2]],
        zeros(FT, nvals),
        zeros(FT, nvals),
        zeros(FT, nvals),
        zeros(FT, nvals),
    )
end

"""
    Ocean(::Type{FT}, grid::AbstractGrid, u, v, temp, ::Type{T} = Float64)

Construct model's ocean.
Inputs: 
    Type{FT} <AbstractFloat> Type for grid's numberical fields - determines
                simulation run type
    grid    <AbstractGrid> model grid
    u       <Real> ocean x-velocity for each grid line
    v       <Real> ocean y-velocity for each grid line
    temp    <Real> temperature at ocean/ice interface per grid cell
Output: 
        Ocean with constant velocity and temperature on each grid line.
"""
function Ocean(
    ::Type{FT},
    grid::AbstractGrid,
    u,
    v,
    temp,
) where {FT <: AbstractFloat}
    nvals = grid.dims .+ 1  # one value per grid line - not grid cell 
    return Ocean(FT, fill(u, nvals), fill(v, nvals), fill(temp, nvals))
end

"""
Atmos velocities in the x-direction (u) and y-direction (v). u and v should
match the size of the corresponding model grid so that there is one x and y
velocity value for each grid cell. Atmos also needs temperature at the
atmosphere/ice interface in each grid cell. Model cannot be constructed if size
of atmos fields and grid do not match.
"""
struct Atmos{FT<:AbstractFloat}
    u::Matrix{FT}
    v::Matrix{FT}
    temp::Matrix{FT}
end

"""
    Atmos(::Type{FT}, u::Matrix, v, temp)

Construct model's atmosphere of type FT.
Inputs:
    Type{FT}    <AbstractFloat> Type for grid's numberical fields - determines
                    simulation run type
    u           <Matrix> atmosphere x-velocity for each grid line
    v           <Matrix> atmosphere y-velocity for each grid line
    temp        <Matrix> temperature at atmosphere/ice interface per grid cell
Output: 
    Atmosphere with provided u, v, and temperature fields converted to given
    type FT.
"""
function Atmos(
    ::Type{FT},
    u,
    v,
    temp,
) where {FT <: AbstractFloat}
    return Atmos(
        convert(Matrix{FT}, u),
        convert(Matrix{FT}, v),
        convert(Matrix{FT}, temp),
    )
end

"""
    Atmos(::Type{FT}, grid, u, v, FT)

Construct model atmosphere of type FT.
Inputs: 
    Type{FT}    <AbstractFloat> Type for grid's numberical fields - determines
                    simulation run type
    grid        <AbstractGrid> model's grid 
    u           <Real> Atmos x-velocity for each grid cell
    v           <Real> Atmos y-velocity for each grid cell
    temp        <Real> temperature at atmopshere/ice interface per grid cell
Output: 
    Atmosphere of type FT with constant velocity and temperature over domain.
"""
function Atmos(
    ::Type{FT},
    grid::AbstractGrid,
    u,
    v,
    temp,
) where FT
    nvals = grid.dims .+ 1  # one value per grid line - not grid cell 
    return Atmos(
        fill(convert(FT, u), nvals),
        fill(convert(FT, v), nvals),
        fill(convert(FT, temp), nvals),
    )
end

"""
    AbstractDirection

An abstract type for the boundary cardinal directions within model domain.
Boundary direction will control behavior of sea ice floes at edges of domain.
"""
abstract type AbstractDirection end

"""
    North<:AbstractDirection

A simple direction type representing if a boundary is the northern boundary in a rectangular domain.
"""
struct North<:AbstractDirection end

"""
    South<:AbstractDirection

A simple direction type representing if a boundary is the souther boundary in a rectangular domain.
"""
struct South<:AbstractDirection end

"""
    East<:AbstractDirection

A simple direction type representing if a boundary is the eastern boundary in a rectangular domain.
"""
struct East<:AbstractDirection end

"""
    West<:AbstractDirection

A simple direction type representing if a boundary is the western boundary in a rectangular domain.
"""
struct West<:AbstractDirection end

"""
    boundary_coords(grid::AbstractGrid, ::Type{North})

Determine coordinates of northen-most boundary of domain if around the edge of the grid.
Inputs:
        grid    <AbstractGrid> model grid
                <Type{North}> boundary direction type
Output:
        PolyVec of boundary coordinates. These coordinates describe a rectangle that has a length 2-times
        the length of the grid in the x-direction, centered on the grid so that there is a buffer of half 
        of the grid on either side. The height is half of the grid in the y-direction. This buffer prevents
        pieces of floes from passing outside the boundary before the next timestep - possibly too cautious.
        If boundary_coords methods are used for each direction, corners will be shared between adjacent boundaries. 
"""
function boundary_coords(grid::AbstractGrid, ::Type{North})
    Δx = (grid.xg[end] - grid.xg[1])/2 # Half of the grid in x
    Δy = (grid.yg[end] - grid.yg[1])/2 # Half of the grid in y
    return grid.yg[end],  # val
        [[[grid.xg[1] - Δx, grid.yg[end]],  # coords
          [grid.xg[1] - Δx, grid.yg[end] + Δy],
          [grid.xg[end] + Δx, grid.yg[end] + Δy], 
          [grid.xg[end] + Δx, grid.yg[end]], 
          [grid.xg[1] - Δx, grid.yg[end]]]]
end

"""
    boundary_coords(grid::AbstractGrid, ::Type{South})

Determine coordinates of southern-most boundary of domain if around the edge of
the grid.
Inputs:
        grid    <AbstractGrid> model grid
                <Type{South}> boundary direction type
Output:
    PolyVec of boundary coordinates. See documentation of North method of this
    function for more details. 
"""
function boundary_coords(grid::AbstractGrid, ::Type{South})
    Δx = (grid.xg[end] - grid.xg[1])/2 # Half of the grid in x
    Δy = (grid.yg[end] - grid.yg[1])/2 # Half of the grid in y
    return grid.yg[1],  # val
        [[[grid.xg[1] - Δx, grid.yg[1] - Δy],  # coords
          [grid.xg[1] - Δx, grid.yg[1]],
          [grid.xg[end] + Δx, grid.yg[1]], 
          [grid.xg[end] + Δx, grid.yg[1] - Δy], 
          [grid.xg[1] - Δx, grid.yg[1] - Δy]]]
end

"""
    boundary_coords(grid::AbstractGrid, ::Type{East})

Determine coordinates of eastern-most boundary of domain if around the edge of
the grid.
Inputs:
        grid    <AbstractGrid> model grid
                <Type{East}> boundary direction type
Output:
    PolyVec of boundary coordinates. See documentation of North method of this
    function for more details. 
"""
function boundary_coords(grid::AbstractGrid, ::Type{East})
    Δx = (grid.xg[end] - grid.xg[1])/2 # Half of the grid in x
    Δy = (grid.yg[end] - grid.yg[1])/2 # Half of the grid in y
    return grid.xg[end],  # val
        [[[grid.xg[end], grid.yg[1] - Δy],  # coords
          [grid.xg[end], grid.yg[end] + Δy],
          [grid.xg[end] + Δx, grid.yg[end] + Δy], 
          [grid.xg[end] + Δx, grid.yg[1] - Δy], 
          [grid.xg[end], grid.yg[1] - Δy]]]
end

"""
    boundary_coords(grid::AbstractGrid, ::Type{West})

Determine coordinates of western-most boundary of domain if around the edge of
the grid.
Inputs:
        grid    <AbstractGrid> model grid
                <Type{West}> boundary direction
Output:
    PolyVec of boundary coordinates. See documentation of North method of this
    function for more details. 
"""
function boundary_coords(grid::AbstractGrid, ::Type{West})
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
The direction given by type D denotes which edge of a domain this boundary could be.

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
    coords::PolyVec{FT}
    val::FT
end

"""
    OpenBoundary(::Type{FT}, ::Type{D}, coords, val)

Creates open boundary with given coords and val, and with the direction as a
type.
Inputs:
    Type{FT}    <AbstractFloat> Type for grid's numberical fields - determines
                    simulation run type
    Type{D}     <AbstractDirection> boundary direction type (north, south, etc.)
    coords      <PolyVec{AbstractFloat}> coordinates of boundary
    val         <AbstractFloat> value defining line that marks edge of domain
Output:
    Open Boundary of type given by direction and defined by given coordinates
    and edge value
"""
OpenBoundary(
    ::Type{FT},
    ::Type{D},
    coords,
    val,
) where {FT <: AbstractFloat, D <: AbstractDirection} =
    OpenBoundary{D, FT}(
        convert(PolyVec{FT}, coords),
        convert(FT, val),
    )


"""
    OpenBoundary(::Type{FT}, ::Type{D}, grid::AbstractGrid)

Creates open boundary on the edge of the grid, and with the direction as a type.
Edge is determined by direction.
Inputs:
    Type{FT}    <AbstractFloat> Type for grid's numberical fields - determines
                    simulation run type
    Type{D}     <AbstractDirection> boundary direction type (north, south, etc.)
    grid        <AbstractGrid> model grid
Outputs:
    Open Boundary on edge of grid given by direction and type. 
"""
function OpenBoundary(
    ::Type{FT},
    ::Type{D},
    grid::AbstractGrid,
) where {FT <: AbstractFloat, D <: AbstractDirection}
    val, coords = boundary_coords(grid, D)
    OpenBoundary(
        FT,
        D,
        coords,
        val,
    )
end

"""
    PeriodicBoundary <: AbstractBoundary

A sub-type of AbstractBoundary that moves a floe from one side of the domain to
the opposite side of the domain when it crosses the boundary, bringing the floe
back into the domain.
"""
struct PeriodicBoundary{D, FT}<:AbstractBoundary{D, FT}
    coords::PolyVec{FT}
    val::FT
end

"""
    PeriodicBoundary(::Type{FT}, ::Type{D}, coords, val)

Creates periodic boundary with given coords and val, and with the direction as a
type.
Inputs:
    Type{FT}    <AbstractFloat> Type for grid's numberical fields - determines
                    simulation run type
    Type{D}     <AbstractDirection> boundary direction type (north, south, etc.)
    coords      <PolyVec{AbstractFloat}> coordinates of boundary
    val         <AbstractFloat> value defining line that marks edge of domain
Output:
    Periodic Boundary of type given by direction and defined by given
    coordinates and edge value
"""
PeriodicBoundary(
    ::Type{FT},
    ::Type{D},
    coords,
    val,
) where {FT <: AbstractFloat, D <: AbstractDirection} =
    PeriodicBoundary{D, FT}(
        convert(PolyVec{FT}, coords),
        convert(FT, val),
    )

"""
    PeriodicBoundary(::Type{FT}, ::Type{D}, grid::AbstractGrid)

Creates periodic boundary on the edge of the grid, and with the direction as a
type. Edge is determined by direction.
Inputs:
    Type{FT}    <AbstractFloat> Type for grid's numberical fields - determines
                    simulation run type
    Type{D}     <AbstractDirection> boundary direction type (north, south, etc.)
    grid        <AbstractGrid> model grid
Outputs:
    Periodic Boundary on edge of grid given by direction and type. 
"""
function PeriodicBoundary(
    ::Type{FT},
    ::Type{D},
    grid::AbstractGrid,
) where {FT <: AbstractFloat, D <: AbstractDirection}
    val, coords = boundary_coords(grid, D)
    PeriodicBoundary(
        FT,
        D,
        coords,
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
    coords::PolyVec{FT}
    val::FT
end

"""
    CollisionBoundary(::Type{FT}, ::Type{D}, coords, val)

Creates collision boundary with given coords and val, and with the direction as
a type.
Inputs:
    Type{FT}    <AbstractFloat> Type for grid's numberical fields - determines
                    simulation run type
    Type{D}     <AbstractDirection> boundary direction type (north, south, etc.)
    coords      <PolyVec{AbstractFloat}> coordinates of boundary
    val         <AbstractFloat> value defining line that marks edge of domain
Output:
    Collision Boundary of type given by direction and defined by given
    coordinates and edge value
"""
CollisionBoundary(
    ::Type{FT},
    ::Type{D},
    coords,
    val,
) where {FT <: AbstractFloat, D <: AbstractDirection} =
    CollisionBoundary{D, FT}(
        convert(PolyVec{FT}, coords),
        convert(FT, val),
    )

"""
    CollisionBoundary(::Type{FT}, ::Type{D}, grid)

Creates collision boundary on the edge of the grid, and with the direction as a
type. Edge is determined by direction.
Inputs:
    grid        <AbstractGrid> model grid
    direction   <AbstractDirection> direction of boundary wall
                <Float> datatype simulation is run in - either Float64 of Float32
Outputs:
        Collision Boundary on edge of grid given by direction. 
"""
function CollisionBoundary(
    ::Type{FT},
    ::Type{D},
    grid::AbstractGrid,
) where {FT <: AbstractFloat, D <: AbstractDirection}
    val, coords = boundary_coords(grid, D)
    CollisionBoundary(
        FT,
        D,
        coords,
        val,
    )
end
"""
    CompressionBC <: AbstractBC

A sub-type of AbstractBoundary that creates a floe along the boundary that moves
towards the center of the domain at the given velocity, compressing the ice
within the domain. This subtype is a mutable struct so that the coordinates and
val can be changed as the boundary moves. The velocity is in [m/s].

NOTE: Not implemented yet!
"""
mutable struct CompressionBoundary{D, FT}<:AbstractBoundary{D, FT}
    coords::PolyVec{FT}
    val::FT
    velocity::FT
end

"""
    CompressionBoundary(::Type{FT}, ::Type{D}, coords, val, velocity)

Creates compression boundary with given coords and val, and with the direction
as a type. It will move towards center of domain, in opposite direction as FT
with given velocity every timestep.
Inputs:
    Type{FT}    <AbstractFloat> Type for grid's numberical fields - determines
                    simulation run type
    Type{D}     <AbstractDirection> boundary direction type (north, south, etc.)
    coords      <PolyVec{AbstractFloat}> coordinates of boundary
    val         <AbstractFloat> value defining line that marks edge of domain
    velocity    <AbstractFloat> value defining velocity with which boundary will
                    move towards center of domain
Output:
    Compression Boundary of type given by direction and defined by given
    coordinates, edge value, and velocity
"""
CompressionBoundary(
    ::Type{FT},
    ::Type{D},
    coords,
    val,
    velocity,
) where {FT <: AbstractFloat, D <: AbstractDirection} =
    CompressionBoundary{D, FT}(
        convert(PolyVec{FT}, coords),
        convert(FT, val),
        convert(FT, velocity),
    )

"""
    CompressionBoundary(::Type{FT}, ::Type{D}, grid, velocity)

Creates compression boundary on the edge of the grid, and with the direction as
a type.
Edge is determined by direction.
Inputs:
        grid        <AbstractGrid> model grid
        direction   <AbstractDirection> direction of boundary wall
        <Float> datatype simulation is run in - either Float64 of Float32
Outputs:
        Open Boundary on edge of grid given by direction. 
"""
function CompressionBoundary(
    ::Type{FT},
    ::Type{D},
    grid::AbstractGrid,
    velocity,
) where {FT <: AbstractFloat, D <: AbstractDirection}
    val, coords = boundary_coords(grid, D)
    CompressionBoundary(FT, D, coords, val, velocity)
end

"""
    NonPeriodicBoundary

Union of all non-peridic boundary types to use as shorthand for dispatch.
"""
const NonPeriodicBoundary = Union{
    OpenBoundary,
    CollisionBoundary,
    CompressionBoundary,
}

"""
    TopographyE{FT}<:AbstractDomainElement{FT}

Singular topographic element with coordinates field storing where the element is
within the grid. These are used to create the desired topography within the
simulation and will be treated as islands or coastline within the model
in that they will not move or break due to floe interactions, but they will
affect floes.
"""
struct TopographyElement{FT}<:AbstractDomainElement{FT}
    coords::PolyVec{FT}
    centroid::Vector{FT}
    rmax::FT

    function TopographyElement{FT}(
        coords::PolyVec{FT},
        centroid::Vector{FT},
        rmax::FT,
    ) where {FT <: AbstractFloat}
        if rmax <= 0
            throw(ArgumentError("Topography element maximum radius must be \
                positive and non-zero."))
        end
        new{FT}(valid_polyvec!(rmholes(coords)), centroid, rmax)
    end

    TopographyElement(
        coords::PolyVec{FT},
        centroid::Vector{FT},
        rmax::FT,
    ) where {FT <: AbstractFloat} =
        TopographyElement{FT}(coords, centroid, rmax)
end

"""
    Topography(::Type{FT}, poly)

Constructor for topographic element with LibGEOS Polygon
Inputs:
    Type{FT}    <AbstractFloat>
    poly        <LibGEOS.Polygon>
Output:
    Topographic element coordinates of type PolyVec{T} with any holes removed
"""
function TopographyElement(
    ::Type{FT},
    poly::LG.Polygon,
) where {FT <: AbstractFloat}
    topo = rmholes(poly)
    centroid = convert(Vector{FT}, find_poly_centroid(topo))
    coords = convert(PolyVec{FT}, find_poly_coords(topo))
    # Move coordinates to be centered at origin to calculate maximum radius
    translate!(
        coords,
        -centroid[1],
        -centroid[2],
    )
    rmax = sqrt(maximum([sum(c.^2) for c in coords[1]]))
    translate!(
        coords,
        centroid[1],
        centroid[2],
    )
    return TopographyElement(coords, centroid, rmax)
end

"""
    Topography(::Type{FT}, coords)

Constructor for topographic element with PolyVec coordinates
Inputs:
    Type{FT}    <AbstractFloat>
    coords      <PolyVec>
Output:
    Topographic element coordinates of type PolyVec{FT} with any holes removed
"""
function TopographyElement(
    ::Type{FT},
    coords::PolyVec,
) where {FT} 
    return TopographyElement(FT, LG.Polygon(coords))
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
}
    north::NB
    south::SB
    east::EB
    west::WB
    topography::StructArray{TopographyElement{FT}}

    function Domain{FT, NB, SB, EB, WB}(
        north::NB,
        south::SB,
        east::EB,
        west::WB,
        topography::StructArray{TopographyElement{FT}},
    ) where {
        FT<:AbstractFloat,
        NB<:AbstractBoundary{North, FT},
        SB<:AbstractBoundary{South, FT},
        EB<:AbstractBoundary{East, FT}, 
        WB<:AbstractBoundary{West, FT},
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
        new{FT, NB, SB, EB, WB}(north, south, east, west, topography)
    end

    Domain(
        north::NB,
        south::SB,
        east::EB,
        west::WB,
        topography::StructArray{TopographyElement{FT}},
    ) where {
        FT<:AbstractFloat,
        NB<:AbstractBoundary{North, FT},
        SB<:AbstractBoundary{South, FT},
        EB<:AbstractBoundary{East, FT},
        WB<:AbstractBoundary{West, FT},
    } =
        Domain{FT, NB, SB, EB, WB}(north, south, east, west, topography)
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


"""
    domain_in_grid(domain, grid)

Checks if given rectangular domain is within given grid and gives user a warning
if domain is not of maximum possible size given grid dimensions.
Inputs:
    domain      <RectangularDomain>
    grid        <AbstractGrid>
Outputs:
    <Boolean> true if domain is within grid bounds, else false
"""
function domain_in_grid(domain::Domain, grid::AbstractGrid)
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
            @warn "At least one wall of domain is smaller than grid. This \
                could lead to unneeded computation. Consider making grid \
                smaller or domain larger."
        end 
        return true
    end
    return false
end

"""
Model which holds grid, ocean, atmos structs, each with the same underlying
float type (either Float32 of Float64) and size. It also holds the domain
information, which includes the topography and the boundaries. It holds a 
StructArray of floe structs, again each relying on the same underlying float
type. Finally, it also holds the maximum floe id used thus far in the
simulation. This should be the length of the floes array at the beginning of the
run. 
"""
mutable struct Model{
    FT<:AbstractFloat,
    GT<:AbstractGrid{FT},
    DT<:Domain{
        FT,
        <:AbstractBoundary,
        <:AbstractBoundary,
        <:AbstractBoundary,
        <:AbstractBoundary,
    },
}
    grid::GT
    ocean::Ocean{FT}
    atmos::Atmos{FT}
    domain::DT
    floes::StructArray{Floe{FT}}  # See floes.jl for floe creation
    max_floe_id::Int              # Maximum id used by any floe

    function Model{FT, GT, DT}(
        grid::GT,
        ocean::Ocean{FT},
        atmos::Atmos{FT},
        domain::DT,
        floes::StructArray{Floe{FT}},
        max_floe_id,
    ) where {
        FT<:AbstractFloat,
        GT<:AbstractGrid{FT},
        DT<:Domain{
            FT,
            <:AbstractBoundary,
            <:AbstractBoundary,
            <:AbstractBoundary,
            <:AbstractBoundary,
        }}
        if !domain_in_grid(domain, grid)
            throw(ArgumentError("Domain does not fit within grid."))
        elseif (
            size(ocean.u) != size(atmos.u) ||
            size(ocean.v) != size(atmos.v) ||
            size(ocean.temp) != size(atmos.temp)
        )
            throw(ArgumentError("Ocean and atmosphere are not on the same grid.\
                This is not supported yet."))
        end
        if any(ocean.temp .< atmos.temp)
            @warn "In at least one grid cell the atmosphere temperature is \
            warmer than the ocean. This is not a situation in which the \
            thermodynamics are setup for right now."
        end
        new{FT, GT, DT}(grid, ocean, atmos, domain, floes, max_floe_id)
    end

    Model(
        grid::GT,
        ocean::Ocean{FT},
        atmos::Atmos{FT},
        domain::DT,
        floes::StructArray{Floe{FT}},
        max_floe_id,
    ) where {
        FT<:AbstractFloat,
        GT<:AbstractGrid{FT},
        DT<:Domain{
            FT,
            <:AbstractBoundary,
            <:AbstractBoundary,
            <:AbstractBoundary,
            <:AbstractBoundary,
        },
    } = 
        Model{FT, GT, DT}(grid, ocean, atmos, domain, floes, max_floe_id)
end

Model(grid, ocean, atmos, domain, floes) = 
    Model(grid, ocean, atmos, domain, floes, length(floes))