using Subzero, StructArrays, Statistics, JLD2, SplitApplyCombine
import LibGEOS as LG

# User Inputs
const type = Float64::DataType

const Lx = 1e5
const Ly = 1e5
const Δgrid = 10000
const h_mean = 0.25
const Δh = 0.0
const Δt = 20
const newfloe_Δt = 500
const coarse_nx = 10
const coarse_ny = 10

# Model instantiation
grid = RegRectilinearGrid(-Lx, Lx, -Ly, Ly, Δgrid, Δgrid)
ocean = Ocean(grid, 0.0, 0.0, 0.0)
atmos = Atmos(zeros(grid.dims .+ 1), zeros(grid.dims .+ 1), fill(-20.0, grid.dims .+ 1))
th = 0:pi/50:2*pi
r = Ly/4+1000
coords1 = splitdims([Lx/2 Lx/2 3*Lx/4 3*Lx/4 Lx+10000 Lx+10000; Ly/2 Ly+10000 Ly+10000 3*Ly/4 3*Ly/4 Ly/2])
coords2 = invert([r * cos.(th) .+ Lx, r * sin.(th) .+ Ly])

floe_arr = StructArray(Floe([c], 0.5, 0.0) for c in [coords1, coords2])
for i in eachindex(floe_arr)
    floe_arr.id[i] = i
end
# flip border overlap from north to south and east to west and visa versa
double_periodic_domain = Domain(PeriodicBoundary(grid, North()), PeriodicBoundary(grid, South()),
                                PeriodicBoundary(grid, East()), PeriodicBoundary(grid, West()))
floe_arr.u[1] = 0.1
floe_arr.u[2] = 0.1
add_ghosts!(floe_arr, double_periodic_domain)
Subzero.timestep_collisions!(floe_arr, 2, double_periodic_domain, zeros(Int, 2), zeros(Int, 2), Subzero.Constants(), 10)

# Domain creation - boundaries and topography
nboundary = PeriodicBoundary(grid, North())
sboundary = PeriodicBoundary(grid, South())
eboundary = PeriodicBoundary(grid, East())
wboundary = PeriodicBoundary(grid, West())

topo = TopographyElement([[[-9.5e4, 7.5e4], [-9.5e4, 9.5e4], [-7.5e4, 9.5e4],
                           [-7.5e4, 7.5e4], [-9.5e4, 7.5e4]]])
topo_arr = StructVector([topo for i in 1:1])

domain = Domain(nboundary, sboundary, eboundary, wboundary, topo_arr)

# Floe instantiation
floe1_coords = [[[7.5e4, 7.5e4], [7.5e4, 9.5e4], [9.5e4, 9.5e4], 
                    [9.5e4, 7.5e4], [7.5e4, 7.5e4]]]
floe1 = Floe(floe1_coords, h_mean, Δh)
floe1.u = 1
floe_arr = StructArray([floe1])

model = Model(grid, ocean, atmos, domain, floe_arr)

# Simulation setup
modulus = 1.5e3*(mean(sqrt.(floe_arr.area)) + minimum(sqrt.(floe_arr.area)))
#consts = Constants(E = modulus)
consts = Constants(E = modulus, Cd_io = 0.0, Cd_ia = 0.0, Cd_ao = 0.0, f = 0.0, μ = 0.0)  # collisions without friction 
simulation = Simulation(model = model, consts = consts, Δt = Δt, nΔt = 2000, COLLISION = true)

# Output setup
gridwriter = GridOutputWriter([GridOutput(i) for i in 1:9], 10, "g.nc", grid, (10, 10))
floewriter = FloeOutputWriter([FloeOutput(i) for i in [3:4; 6; 9:11; 22:26]], 30, "f.nc", grid)

# Run simulation
run!(simulation, [floewriter])