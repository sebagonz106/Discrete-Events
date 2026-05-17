"""
    main.jl

Main entry point for experiments.

Usage:
    julia main.jl 1 [seed]          # Simple evolution experiment
    julia main.jl 2 [seed]          # Parameter comparison experiment

Arguments:
    - experiment_id: 1 or 2
    - seed (optional): Random seed for reproducibility
"""

# Include the simulator bundle (it brings its own sub-modules under PopulationSimulator)
include("src/population_sim.jl")

# Bring commonly used simulator symbols into Main scope so experiments can refer to them unqualified
using .PopulationSimulator.SimulatorConfig: SimConfig, DEFAULT_CONFIG
using .PopulationSimulator.SimulatorEngine: run_simulation

include("src/experiments/base.jl")
include("src/experiments/simple_evolution.jl")
include("src/experiments/parameter_comparison.jl")

# ============================================================================
# Experiment Definitions
# ============================================================================

"""
    create_simple_evolution_experiment(seed::Union{Int64, Nothing})::SimpleEvolutionExperiment

Create a simple evolution experiment: population evolves with fixed parameters.
"""
function create_simple_evolution_experiment(seed::Union{Int64, Nothing})::SimpleEvolutionExperiment
    config = ExperimentConfig(
        "Population Evolution (100 years)",
        500,
        seed,
        "Simulation of population evolution over 100 years with fixed parameters. " *
        "Used population_size=5000 with 0.5 uniform distribution and seed=16. " *
        "Results show mean and standard error across multiple runs."
    )
    
    sim_config = SimConfig(
        population_size = 2000,
        male_population = 500,
        fertility_age_min = 12,
        fertility_age_max = 70,
        simulation_years = 100,
        age_max = 125
    )
    
    return SimpleEvolutionExperiment(config, sim_config)
end

"""
    create_parameter_comparison_experiment(seed::Union{Int64, Nothing})::ParameterComparisonExperiment

Create a parameter comparison experiment.
Run simulations per parameter value for statistical relevance.
"""
function create_parameter_comparison_experiment(seed::Union{Int64, Nothing})::ParameterComparisonExperiment
    pop_config = ExperimentConfig(
        "Parameter Sensitivity: Population Size",
        250,
        seed,
        "Comparison of how initial population size affects population dynamics. " *
        "Each point represents mean across multiple runs with error bars (standard error)."
    )
    
    pop_base_sim_config = SimConfig(
        fertility_age_min = 12,
        fertility_age_max = 70,
        simulation_years = 50,
        age_max = 125
    )
    
    pop_values = [200, 400, 600, 800, 1000, 1200, 1400, 1600, 1800, 2000]
    
    male_pop_config = ExperimentConfig(
        "Parameter Sensitivity: Male Population Size",
        250,
        seed,
        "Comparison of how initial male population size affects population dynamics. " *
        "Each point represents mean across multiple runs with error bars (standard error)."
    )
    
    male_pop_base_sim_config = SimConfig(
        population_size = 2000,
        fertility_age_min = 12,
        fertility_age_max = 70,
        simulation_years = 30,
        age_max = 125
    )
    
    male_pop_values = [0, 200, 400, 600, 800, 1000, 1200, 1400, 1600, 1800, 2000]

    return ParameterComparisonExperiment(
        male_pop_config,
        male_pop_base_sim_config,
        "male_population",
        male_pop_values
    )
end

# ============================================================================
# Main Entry Point
# ============================================================================

function main()

    if length(ARGS) < 1
        print_usage()
        return false
    end
    
    # Parse experiment ID
    exp_id = parse(Int64, ARGS[1])
    
    # Parse optional seed
    seed = nothing
    if length(ARGS) >= 2
        seed = parse(Int64, ARGS[2])
        println("Using provided seed: $seed")
    else
        println("No seed provided. Using random seed for variability.")
    end
    
    # Select and run experiment
    experiment = nothing
    
    if exp_id == 1
        println("Creating Simple Evolution Experiment...")
        experiment = create_simple_evolution_experiment(seed)
    elseif exp_id == 2
        println("Creating Parameter Comparison Experiment...")
        experiment = create_parameter_comparison_experiment(seed)
    else
        println("Error: Unknown experiment ID: $exp_id")
        print_usage()
        return false
    end
    
    println()
    
    # Run experiment
    success = run(experiment)
    
    return success
end

function print_usage()
    println()
    println("=" ^ 70)
    println("DISCRETE EVENTS SIMULATION - EXPERIMENT RUNNER")
    println("=" ^ 70)
    println()
    println("Usage:")
    println("  julia main.jl <experiment_id> [seed]")
    println()
    println("Arguments:")
    println("  experiment_id: 1 = Simple Evolution")
    println("                 2 = Parameter Comparison")
    println("  seed (optional): Integer seed for reproducibility")
    println()
    println("Examples:")
    println("  julia main.jl 1               # Run simple evolution with random seed")
    println("  julia main.jl 1 42            # Run simple evolution with seed=42")
    println("  julia main.jl 2               # Run parameter comparison with random seed")
    println("  julia main.jl 2 12345         # Run parameter comparison with seed=12345")
    println()
    println("=" ^ 70)
    println()
end

# ============================================================================
# Entry Point
# ============================================================================

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    success = main()
    exit(success ? 0 : 1)
end
