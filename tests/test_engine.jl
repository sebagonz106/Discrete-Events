#!/usr/bin/env julia
# Test script to validate simulator engine (annual hub and event handlers)

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

println("=== TEST: Simulator Engine ===")

# Load implementation
include("../src/population_sim.jl")

# Alias to modules
const PS = PopulationSimulator.SimulatorEngine
const Config = PopulationSimulator.SimulatorConfig
const PM = PopulationSimulator.PopulationManager
const PT = PopulationSimulator.ProbabilityTables
const EE = PopulationSimulator.EventEngine

# Small config for quick test
config = Config.SimConfig(
    population_size=1000,
    simulation_years=10,
    age_max=100,
    fertility_age_min=12,
    fertility_age_max=50,
    pair_bond_age_min=12,
    age_distribution_interval=5,
    validate_consistency=true,
    verbose_logging=true,
    random_seed=12345
)

# Run simulation in try/catch to surface errors
try
    println("Initializing and running simulation (10 years, 1000 people)...")
    state = PS.run_simulation(config; export_results=true)
    println("Simulation completed. Current day: ", state.current_time_days)

    # Basic assertions
    @assert state.current_year <= config.simulation_years "Simulation ran past configured years"
    total_pop = PM.get_population_size(state.population)
    println("Final population: ", total_pop)

    # Check annual statistics exist
    if length(state.population.annual_stats) == 0
        println("WARNING: No annual statistics were recorded.")
    else
        println("Recorded years: ", [s.year for s in state.population.annual_stats])
        println("Sample stats (last year): ")
        last = state.population.annual_stats[end]
        println("  population=", last.population_count, ", births=", last.births, ", deaths=", last.deaths)
    end

    println("\nTEST PASSED: Simulator engine ran without runtime errors and exported results.")
catch e
    println("TEST FAILED: Error during simulation run:")
    println(e)
    rethrow()
end
