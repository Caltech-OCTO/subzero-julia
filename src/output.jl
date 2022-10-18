"""
Structs and functions to calculate and write output from the simulation
"""

abstract type AbstractOutputWriter{FT <: AbstractFloat} end

struct GridOutputWriter{FT}<:AbstractOutputWriter{FT}
    nΔtout::Int
end

struct FloeOutputWriter{FT}<:AbstractOutputWriter{FT}
    nΔtout::Int
end


"""
    CoarseGridData{FT<:AbstractFloat}

Data averaged over a coarse grid covering the domain. Each field is the size of the coarse grid, with one value per coarse grid square, which is the average of mutliple grid squares in finer resolution grid that the simulation is run using. This data is used for plotting and is saved to be able to examine model progress and data. If all data is desired on the same resolution as the model, the coarse grid should be equal to the model grid and therefore the size of each of these fields will be the same as the model grid's dimensions. Each field must have the same dimensions to be a valid struct.
"""
struct OutputGridData{FT<:AbstractFloat}
    u::Matrix{FT}
    v::Matrix{FT}
    du::Matrix{FT}
    dv::Matrix{FT}
    stress::Matrix{FT}
    stressxx::Matrix{FT}
    stressxy::Matrix{FT}
    stressyx::Matrix{FT}
    stressyy::Matrix{FT}
    strainux::Matrix{FT}
    strainuy::Matrix{FT}
    strainvx::Matrix{FT}
    strainvy::Matrix{FT}
    si_frac::Matrix{FT}
    over::Matrix{FT}
    mass::Matrix{FT}
    area::Matrix{FT}
    height::Matrix{FT}

    OutputGridData(u, v, du, dv, stress, stressxx, stressxy, stressyx, stressyy,
                 strainux, strainuy, strainvx, strainvy, si_frac, over, mtot, area, height) = 
                 (size(u) == size(v) == size(du) == size(dv) == size(stress) == size(stressxx) == size(stressxy) == size(stressyx) == 
                 size(stressyy) == size(strainux) ==  size(strainuy) ==
                 size(strainvx) == size(strainvy) == size(si_frac) ==
                 size(over) == size(mtot) == size(area) == size(height)) ?
                 new{eltype(u)}(u, v, du, dv, stress, stressxx, stressxy, stressyx, stressyy, strainux, strainuy, strainvx, strainvy, si_frac, over, mtot, area, height) :
                 throw(ArgumentError("Size of coarse grid data matrices are not uniform between all of the fields."))
end

"""
    CoarseGridData(coarse_nx, coarse_ny, t::Type{T} = Float64)

Initialize all fields to correct size matricies where all values are 0s.

Inputs:
        dims        <Vector{Float}> dimensions of output data grid
        t           <Type> datatype to convert grid fields - must be a Float!
Outputs:
    OutputGridData where each field is a matrix of dimensions coarse_nx by coarse_ny and all elements of each matrix are 0 of type T. 
"""
function OutputGridData(dims, t::Type{T} = Float64) where T
    u = zeros(T, dims[1], dims[2])
    v = zeros(T, dims[1], dims[2])
    du = zeros(T, dims[1], dims[2])
    dv = zeros(T, dims[1], dims[2])
    stress = zeros(T, dims[1], dims[2])
    stressxx = zeros(T, dims[1], dims[2])
    stressxy = zeros(T, dims[1], dims[2])
    stressyx = zeros(T, dims[1], dims[2])
    stressyy = zeros(T, dims[1], dims[2])
    strainux = zeros(T, dims[1], dims[2])
    strainuy = zeros(T, dims[1], dims[2])
    strainvx = zeros(T, dims[1], dims[2])
    strainvy = zeros(T, dims[1], dims[2])
    si_frac = zeros(T, dims[1], dims[2])
    over = zeros(T, dims[1], dims[2])
    mass = zeros(T, dims[1], dims[2])
    area = zeros(T, dims[1], dims[2])
    height = zeros(T, dims[1], dims[2])
    return OutputGridData(u, v, du, dv, stress, stressxx, stressxy, stressyx,
                          stressyy, strainux, strainuy, strainvx, strainvy, si_frac, over, mass, area, height)
end

#nΔtout::Int = 150               # Output frequency in timesteps to save
                                # cgrid_data and floe data
#Δtpics::Int = 150               # Timesteps between saving images

#AVERAGE::Bool = false           # If true, average coarse grid data in time

# have abstract output writer 

# grid output writer and floe output writer

# each output writer has the same time frequency and same grid size

# ways to get/calculate each field that is within the output writer

function reset_output_grid!(data)
    fill!(data.u, 0.0)
    fill!(data.v, 0.0)
    fill!(data.du, 0.0)
    fill!(data.dv, 0.0)
    fill!(data.stress, 0.0)
    fill!(data.stressxx, 0.0)
    fill!(data.stressxy, 0.0)
    fill!(data.stressyx, 0.0)
    fill!(data.stressyy, 0.0)
    fill!(data.strainux, 0.0)
    fill!(data.strainuy, 0.0)
    fill!(data.strainvx, 0.0)
    fill!(data.strainvy, 0.0)
    fill!(data.si_frac, 0.0)
    fill!(data.over, 0.0)
    fill!(data.mass, 0.0)
    fill!(data.area, 0.0)
    fill!(data.height, 0.0)
end

function calc_eulerian_data(floes, topography, cgrid, outdata)
    live_floes = filter(f -> f.alive, floes)
    Δx = cgrid.xg[2] - cgrid.xg[1]
    Δy = cgrid.yg[2] - cgrid.yg[1]
    cell_rmax = sqrt(Δx^2 + Δy^2)
    reset_output_grid!(outdata)
    xgrid, ygrid = grids_from_lines(cgrid.xc, cgrid.yc)
    floe_centroids = live_floes.centroid
    floe_rmax = live_floes.rmax


    potential_interactions = zeros(cgrid.dims[1], cgrid.dims[2], length(floes))
    # Identify all floes that could potentially have a piece that overlaps the coarse areas
    for i in eachindex(floes)
        pint = sqrt.((xgrid .- floe_centroids[i][1]).^2 .+ (ygrid .- floe_centroids[i][2]).^2) .- (floe_rmax[i] + cell_rmax)
        pint[pint .> 0] .= 0
        pint[pint .< 0] .= 1
        potential_interactions[:,:,i] = pint
    end

    for j in 1:cgrid.dims[2]
        for i in 1:cgrid.dims[1]
            pint = potential_interactions[i,j,:]
            if sum(pint) > 0
                cell_poly = LG.Polygon(cell_coords(cgrid.xg[j], cgrid.xg[j+1], cgrid.yg[i], cgrid.yg[i+1]))
                cell_poly = if length(topography) > 0
                    topography_poly = LG.MultiPolygon([t.coords for t in topography])
                    LG.difference(cell_poly, topography_poly)
                end
                floeidx = collect(1:length(floes))[pint .== 1]
                overlap_polys = [LG.intersection(cell_poly, LG.Polygon(floes[idx].coords)) for idx in floeidx]
                overlap_areas = [LG.area(poly) for poly in overlap_polys]
                floeidx = floeidx[overlap_areas .> 0]
                overlap_areas = overlap_areas[overlap_areas .> 0]
                overfloes = floes[floeidx]

                floe_areas = overfloes.area
                area_ratios = overlap_areas ./ floe_areas
                area_tot = sum(overlap_areas)

                floe_masses = overfloes.mass
                mass_tot = sum(floe_masses .* area_ratios)
                # mass and area ratio
                ma_ratios = area_ratios .* floe_masses ./ mass_tot

                if mass_tot>0
                    outdata.u[i, j] = sum(overfloes.u .* ma_ratios)
                    outdata.v[i, j] = sum(overfloes.v .* ma_ratios)
                    outdata.du[i, j] = sum(overfloes.p_dudt .* ma_ratios)
                    outdata.dv[i, j] = sum(overfloes.p_dvdt .* ma_ratios)
                    # need to add overlap area, stress, and strain!
                    outdata.si_frac[i, j] = area_tot/LG.area(cell_poly)
                    outdata.over[i, j] = 
                    outdata.mass[i, j] = mass_tot
                    outdata.area[i, j] = area_tot
                    outdata.height[i, j] = sum(overfloes.height .* ma_ratios)
                end  
            end
        end
    end

end

