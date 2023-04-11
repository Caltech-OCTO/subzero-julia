"""
    calc_total_energy(u, v, mass, ξ, moment)

Calculates linear and rotational energy for one timestep given the floe's
velocities, mass, and moment of intertia.
Inputs:
    u       <Vector{Real}> list of floes' u velocities
    v       <Vector{Real}> list of floes' v velocities
    mass    <Vector{Real}> list of floes' masses
    ξ       <Vector{Real}> list of floes' angular velocities
    moment  <Vector{Real}> list of floes' moments of intertia
Outputs:
    linear      <Real> total linear kinetic energy generated by the floes
    rotational  <Real> total rotational kinetic energy generated by the floes
"""
function calc_kinetic_energy(u, v, mass, ξ, moment)
    linear = sum(0.5 * mass .* (u.^2 .+ v.^2))
    rotational = sum(0.5 * moment .* ξ.^2)
    return linear, rotational
end

"""
    calc_linear_momentum(u, v, mass)

Calculates linear momentum for one timestep given the floe's
velocities and mass.
Inputs:
    u       <Vector{Real}> list of floes' u velocities
    v       <Vector{Real}> list of floes' v velocities
    mass    <Vector{Real}> list of floes' masses
Outputs:
    <Real> total linear momentum in the x-direction from floes
    <Real> total linear momentum in the y-direction from floes
"""
function calc_linear_momentum(u, v, mass)
    linear_x = mass .* u
    linear_y = mass .* v
    return sum(linear_x), sum(linear_y)
end

"""
    calc_angular_momentum(u, v, mass, ξ, moment, x, y)

Calculates angular momentum for one timestep given the floe's velocities, mass,
moment of intertia, and centroid position.
Inputs:
    u       <Vector{Real}> list of floes' u velocities
    v       <Vector{Real}> list of floes' v velocities
    mass    <Vector{Real}> list of floes' masses
    ξ       <Vector{Real}> list of floes' angular velocities
    moment  <Vector{Real}> list of floes' moments of intertia
    x       <Vector{Real}> list of floes' centroid x-value
    y       <Vector{Real}> list of floes' centroid y-value
Outputs:
    <Real> total spin angular momentum from the floes
    <Real> total orbital angular momentum from the floes
"""
function calc_angular_momentum(u, v, mass, ξ, moment, x, y)
    angular_spin = moment .* ξ
    angular_orbital = zeros(length(x))
    for i in eachindex(x)
        rvec = [x[i], y[i], 0]
        vvec = [u[i], v[i], 0]
        angular_orbital[i] = mass[i] * cross(rvec, vvec)[3]
    end
    return sum(angular_spin), sum(angular_orbital)
end

"""
    plot_conservation(
        linear_energy,
        rotational_energy,
        linear_x_momentum,
        linear_y_momentum,
        angular_spin_momentum,
        angular_orbital_momentum,
        dir,
    )

Takes in vectors of energy and momentum at each simulation timestep and plots
conservation over time. Plots are saved to given directory. Also prints total
change in both kinetic energy and momentum from beginning to end of simulation
to terminal. 
Inputs:
    linear_energy               <Vector{Real}> list of total energy from x and y
                                    motion per timestep
    rotational_energy           <Vector{Real}> list of total energy from
                                    rotational motion per timestep
    linear_x_momentum           <Vector{Real}> list of total momentum from x
                                    motion per timestep
    linear_y_momentum           <Vector{Real}> list of total momentum from y
                                    motion per timestep
    angular_spin_momentum       <Vector{Real}> list of total momentum from floes
                                    spinning around their own center of masses
                                    per timestep
    angular_orbital_momentum    <Vector{Real}> list of total momentum from floes
                                    spinning around origin per timestep
    dir                         <String> directory to save images to
Outputs:
    Δenergy          <Float> % change in energy from first to last timestep
    Δxmomentum       <Float> % change in x momentum from first to last timestep
    Δymomentum       <Float> % change in y momentum from first to last timestep
    Δangularmomentum <Float> % change in angular momentum from first to last
                        timestep
    Also saves energy and momentum plots over time to given directory
"""
function plot_conservation(
    linear_energy,
    rotational_energy,
    linear_x_momentum,
    linear_y_momentum,
    angular_spin_momentum,
    angular_orbital_momentum,
    dir,
)
    # Energy conservation
    total_energy = linear_energy .+ rotational_energy
    # Plot energy
    plot(
        [linear_energy rotational_energy total_energy],
        title = "Total Kinetic Energy",
        ylabel = "[N]",
        label=["Linear energy" "Rotational energy" "Total energy"]
    )
    savefig(joinpath(dir, "total_energy_conservation.png"))

    # Momentum conservation
    # Plot momentum
    plot(
        [linear_x_momentum],
        title = "X Momentum",
        ylabel = "[N * s]",
        label=["x"]
    )
    savefig(joinpath(dir, "momentum_x_conservation.png"))
    plot(
        [linear_y_momentum],
        title = "Y Momentum",
        ylabel = "[N * s]",
        label=["y"]
    )
    savefig(joinpath(dir, "momentum_y_conservation.png"))

    total_angular_momentum = angular_spin_momentum .+ angular_orbital_momentum
    plot(
        [angular_spin_momentum angular_orbital_momentum total_angular_momentum],
        title = "Angular Momentum",
        ylabel = "[N * s]",
        label=["Spin momentum" "Orbital momentum" "Total angular momentum"]
    )
    savefig(joinpath(dir, "momentum_angular_conservation.png"))
    return
end

"""
    check_energy_momentum_conservation_julia(filename, dir, verbose)

Calculates total kinetic energy and momentum at each timestep and plots the
output to check for conservation from floe outputwriter file. Also gives percent
change in energy and momentum from first to last timestep in terminal.
Inputs:
    filename    <String> floe outputwriter filename + path
    dir         <String> directory to save total energy and momentum
                    conservation plots
    plot        <Bool> plots energy and momentum over time if true
Outputs:
    Δenergy    <Float> percentage change in energy from first to last timestep
    Δxmomentum       <Float> % change in x momentum from first to last timestep
    Δymomentum       <Float> % change in y momentum from first to last timestep
    Δangularmomentum <Float> % change in angular momentum from first to last
                        timestep
    Also saves energy and momentum plots over time to given directory if plots
    is true
"""
function check_energy_momentum_conservation_julia(
    filename,
    dir = ".",
    plot = true,
)
    file = jldopen(filename, "r")
    tsteps = keys(file["centroid"])
    ntsteps = length(tsteps)
    linear_energy = zeros(ntsteps)
    rotational_energy = zeros(ntsteps)
    linear_x_momentum = zeros(ntsteps)
    linear_y_momentum = zeros(ntsteps)
    angular_spin_momentum = zeros(ntsteps)
    angular_orbital_momentum = zeros(ntsteps)
    for i in eachindex(tsteps)
        t = tsteps[i]
        # Needed values
        original_idx = file["ghost_id"][t] .== 0
        mass = file["mass"][t][original_idx]
        moment = file["moment"][t][original_idx]
        u = file["u"][t][original_idx]
        v = file["v"][t][original_idx]
        ξ = file["ξ"][t][original_idx]
        centroid = file["centroid"][t][original_idx]
        x = first.(centroid)
        y = last.(centroid)
        # calculations
        linear_energy[i], rotational_energy[i] = calc_kinetic_energy(
            u,
            v,
            mass,
            ξ,
            moment,
        )
        linear_x_momentum[i], linear_y_momentum[i] = calc_linear_momentum(
            u,
            v,
            mass,
        )
        angular_spin_momentum[i], angular_orbital_momentum[i] = calc_angular_momentum(
            u,
            v,
            mass,
            ξ,
            moment,
            x,
            y,
        )
    end
    close(file)
    if plot
        plot_conservation(
            linear_energy,
            rotational_energy,
            linear_x_momentum,
            linear_y_momentum,
            angular_spin_momentum,
            angular_orbital_momentum,
            dir,
        )
    end
    return linear_energy .+ rotational_energy,
        linear_x_momentum,
        linear_y_momentum,
        angular_spin_momentum .+ angular_orbital_momentum
end

"""
    check_energy_momentum_conservation_matlab(mat_path, dir, plot)

Calculates total kinetic energy and momentum at each timestep and plots the
output to check for conservation from MATLAB verion of model output. The
mat_path should lead to the Floes file within the MATLAB version of the model.
Also givesnpercent change in energy and momentum from first to last timestep in
terminal.
Inputs:
    mat_path    <String> path to MATLAB version's Floe folder 
    dir         <String> directory to save total energy and momentum
                    conservation plots
    plot        <Bool> plots energy and momentum over time if true
Outputs:
    Δenergy    <Float> percentage change in energy from first to last timestep
    Δxmomentum       <Float> % change in x momentum from first to last timestep
    Δymomentum       <Float> % change in y momentum from first to last timestep
    Δangularmomentum <Float> % change in angular momentum from first to last
                        timestep
    Also saves energy and momentum plots over time to given directory if plots
    is true
"""
function check_energy_momentum_conservation_matlab(mat_path,
    dir = ".",
    plot = true,
)
    mat_files = readdir(mat_path)
    mat_files = mat_files[last.(splitext.(mat_files)) .== ".mat"]
    ntsteps = length(mat_files)
    linear_energy = zeros(ntsteps)
    rotational_energy = zeros(ntsteps)
    linear_x_momentum = zeros(ntsteps)
    linear_y_momentum = zeros(ntsteps)
    angular_spin_momentum = zeros(ntsteps)
    angular_orbital_momentum = zeros(ntsteps)
    for i in eachindex(mat_files)
        mat_data = matread(joinpath(mat_path, mat_files[i]))
        # Needed values
        mass = mat_data["Floe"]["mass"]'
        moment = mat_data["Floe"]["inertia_moment"]'
        u = mat_data["Floe"]["Ui"]'
        v = mat_data["Floe"]["Vi"]'
        ξ = mat_data["Floe"]["ksi_ice"]'
        x = mat_data["Floe"]["Xi"]'
        y = mat_data["Floe"]["Yi"]'
        # calculations
        linear_energy[i], rotational_energy[i] = calc_kinetic_energy(
            u,
            v,
            mass,
            ξ,
            moment,
        )
        linear_x_momentum[i], linear_y_momentum[i]= calc_linear_momentum(
            u,
            v,
            mass,
        )
        angular_spin_momentum[i], angular_orbital_momentum[i] = calc_angular_momentum(
            u,
            v,
            mass,
            ξ,
            moment,
            x,
            y,
        )
    end
    if plot
        plot_conservation(
            linear_energy,
            rotational_energy,
            linear_x_momentum,
            linear_y_momentum,
            angular_spin_momentum,
            angular_orbital_momentum,
            dir,
        )
    end
    return linear_energy .+ rotational_energy,
    linear_x_momentum,
    linear_y_momentum,
    angular_spin_momentum .+ angular_orbital_momentum
end