"""
    parameter_comparison.jl

ParameterComparisonExperiment: Run multiple simulations for each of several parameter values.
Compares how a varied parameter affects final metrics (population, sex ratio, avg age).
Also computes growth rate and other summary statistics.
"""

using Random
using DataFrames
using CSV
using Statistics

# ============================================================================
# ParameterComparisonExperiment Type
# ============================================================================

struct ParameterComparisonExperiment <: AbstractExperiment
    config::ExperimentConfig
    base_sim_config::SimConfig
    param_to_vary::String  # e.g., "population_size", "fertility_age_min"
    param_values::Vector   # e.g., [100, 500, 1000]
end

# ============================================================================
# Helper Functions
# ============================================================================

"""
    extract_final_metrics(results_data::DataFrame, initial_pop::Float64)::Dict{String, Float64}

Extract final year metrics from results CSV.
Returns dict with keys: population, sex_ratio, avg_age, males, females, growth_rate.
"""
function extract_final_metrics(results_data::DataFrame, initial_pop::Float64)::Dict{String, Float64}
    last_row = last(eachrow(results_data))

    population = Float64(last_row.population)
    sex_ratio = hasproperty(last_row, :sex_ratio) ? Float64(last_row.sex_ratio) : 0.0
    avg_age = hasproperty(last_row, :median_age) ? Float64(last_row.median_age) : 0.0

    # Reconstruct males/females from sex_ratio = males / females
    males = 0.0
    females = 0.0
    if sex_ratio > 0
        females = population / (1.0 + sex_ratio)
        males = population - females
    else
        females = population
        males = 0.0
    end

    # Growth rate: (final - initial) / initial
    growth_rate = initial_pop > 0 ? (population - initial_pop) / initial_pop : 0.0

    return Dict(
        "population" => population,
        "sex_ratio" => sex_ratio,
        "avg_age" => avg_age,
        "males" => males,
        "females" => females,
        "growth_rate" => growth_rate
    )
end

"""
    find_latest_export_files(results_base_dir::String)::Tuple{String, String, String, String}

Find the latest timestamped export files in results/ directory.
Return tuple (results_csv, age_csv, timeline_csv, config_json).
"""
function find_latest_export_files(results_base_dir::String)::Tuple{String, String, String, String}
    files = readdir(results_base_dir)
    results_files = filter(f -> endswith(f, "_results.csv"), files)

    if isempty(results_files)
        error("No export files found in $results_base_dir")
    end

    full_paths = [joinpath(results_base_dir, f) for f in results_files]
    mtimes = map(f -> stat(f).mtime, full_paths)
    latest_idx = argmax(mtimes)
    latest_file = results_files[latest_idx]
    latest_timestamp = replace(latest_file, "_results.csv" => "")

    results_csv = joinpath(results_base_dir, "$(latest_timestamp)_results.csv")
    age_csv = joinpath(results_base_dir, "$(latest_timestamp)_population_age.csv")
    timeline_csv = joinpath(results_base_dir, "$(latest_timestamp)_timeline.csv")
    config_json = joinpath(results_base_dir, "$(latest_timestamp)_config.json")

    return (results_csv, age_csv, timeline_csv, config_json)
end

# ============================================================================
# Main Experiment Function
# ============================================================================

function run(exp::ParameterComparisonExperiment)::Bool
    println("=" ^ 70)
    println("Starting Parameter Comparison Experiment")
    println("=" ^ 70)
    println("Varying parameter: $(exp.param_to_vary)")
    println("Values to test: $(exp.param_values)")
    println()

    config = exp.config
    base_sim_config = exp.base_sim_config

    # Determine base seed
    if config.seed !== nothing
        base_seed = config.seed
    else
        base_seed = rand(1:10^9)
    end
    println("Base seed for simulations: $base_seed (will increment per run)")

    # Ensure output directory exists
    aggregated_dir = ensure_aggregated_results_dir()
    timestamp = generate_timestamp()

    # Store metrics for each parameter value
    aggregated_results = DataFrame(
        param_value = Union{Int64, Float64}[],
        population_final_mean = Float64[],
        population_final_se = Float64[],
        sex_ratio_final_mean = Float64[],
        sex_ratio_final_se = Float64[],
        avg_age_final_mean = Float64[],
        avg_age_final_se = Float64[],
        growth_rate_mean = Float64[],
        growth_rate_se = Float64[],
        males_final_mean = Float64[],
        females_final_mean = Float64[]
    )

    # Iterate over parameter values
    for (idx, param_val) in enumerate(exp.param_values)
        println("-" ^ 70)
        println("Parameter value $idx/$(length(exp.param_values)): $param_val")
        println("-" ^ 70)

        # Modify sim_config for this parameter value
        current_sim_config = modify_sim_config(base_sim_config, exp.param_to_vary, param_val)
        initial_pop = Float64(current_sim_config.population_size)

        pop_values = Float64[]
        sex_ratio_values = Float64[]
        avg_age_values = Float64[]
        growth_rate_values = Float64[]
        males_values = Float64[]
        females_values = Float64[]

        # Run num_simulations for this parameter value
        for sim_idx in 1:config.num_simulations
            print("  Simulation $sim_idx/$(config.num_simulations)...\r")

            # Prepare per-simulation seed and config
            sim_seed = base_seed + (sim_idx - 1)
            sim_cfg = modify_sim_config(current_sim_config, "random_seed", sim_seed)

            # Run simulation with export
            run_simulation(sim_cfg; export_results=true)

            # Find and load the latest exported results CSV
            results_dir = PopulationSimulator.PopulationManager.ensure_results_dir()
            (results_csv, _, _, _) = find_latest_export_files(results_dir)

            results_df = CSV.read(results_csv, DataFrame)
            final_metrics = extract_final_metrics(results_df, initial_pop)

            push!(pop_values, final_metrics["population"])
            push!(sex_ratio_values, final_metrics["sex_ratio"])
            push!(avg_age_values, final_metrics["avg_age"])
            push!(growth_rate_values, final_metrics["growth_rate"])
            push!(males_values, final_metrics["males"])
            push!(females_values, final_metrics["females"])
        end

        println()

        # Calculate statistics
        pop_mean, _, pop_se = calculate_stats(pop_values)
        sr_mean, _, sr_se = calculate_stats(sex_ratio_values)
        age_mean, _, age_se = calculate_stats(avg_age_values)
        gr_mean, _, gr_se = calculate_stats(growth_rate_values)
        males_mean, _, _ = calculate_stats(males_values)
        females_mean, _, _ = calculate_stats(females_values)

        push!(aggregated_results, (
            param_val, pop_mean, pop_se, sr_mean, sr_se, age_mean, age_se,
            gr_mean, gr_se, males_mean, females_mean
        ))
    end

    # Save RESULTS CSV (includes all metrics)
    # Rename the first column from :param_value to the actual parameter name (e.g., "population_size")
    rename!(aggregated_results, :param_value => Symbol(exp.param_to_vary))
    results_filepath = joinpath(aggregated_dir, "param_$(timestamp)_results.csv")
    CSV.write(results_filepath, aggregated_results)
    println("✓ Saved results to: $results_filepath")

    # # Save PLOT CSV (only columns needed for plotting)
    # plot_df = select(aggregated_results,
    #     :param_value,
    #     :population_final_mean, :population_final_se,
    #     :sex_ratio_final_mean, :sex_ratio_final_se,
    #     :avg_age_final_mean, :avg_age_final_se,
    #     :growth_rate_mean, :growth_rate_se
    # )
    # plot_filepath = joinpath(aggregated_dir, "$(timestamp)_plot.csv")
    # CSV.write(plot_filepath, plot_df)
    # println("✓ Saved plot data to: $plot_filepath")

    # Save CONFIG JSON
    metadata = ExperimentMetadata(
        timestamp,
        config,
        base_sim_config,
        Dict(
            "experiment_type" => "parameter_comparison",
            "varied_parameter" => exp.param_to_vary,
            "parameter_values" => exp.param_values
        )
    )
    config_filepath = joinpath(aggregated_dir, "param_$(timestamp)_config.json")
    save_config_json(metadata, config_filepath)
    println("✓ Saved config to: $config_filepath")

    # Save DESCRIPTION JSON (for Python plotter)
    description = Dict(
        "type" => "parameter_comparison",
        "experiment_name" => config.name,
        "experiment_description" => config.description,
        "parameters" => Dict(
            "num_simulations" => config.num_simulations,
            "simulation_years" => base_sim_config.simulation_years,
            "varied_parameter" => exp.param_to_vary,
            "parameter_values" => exp.param_values
        ),
        "axes" => Dict(
            "x" => exp.param_to_vary,
            "x_label" => exp.param_to_vary,
            "y_columns" => ["population_final_mean", "sex_ratio_final_mean", "avg_age_final_mean", "growth_rate_mean"],
            "error_columns" => ["population_final_se", "sex_ratio_final_se", "avg_age_final_se", "growth_rate_se"]
        ),
        # Point the description to the results CSV since plot CSV is not produced
        "data_file" => "param_$(timestamp)_results.csv"
    )
    desc_filepath = joinpath(aggregated_dir, "param_$(timestamp)_description.json")
    save_description_json(description, desc_filepath)
    println("✓ Saved description to: $desc_filepath")

    println()
    println("=" ^ 70)
    println("Parameter Comparison Experiment completed successfully!")
    println("=" ^ 70)

    return true
end
