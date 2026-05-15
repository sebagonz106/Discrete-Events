"""
    simple_evolution.jl

SimpleEvolutionExperiment: Run multiple simulations with fixed parameters.
Aggregates metrics (population, sex ratio, average age) per year across simulations.
"""

using Random
using DataFrames
using CSV
using Statistics

# ============================================================================
# SimpleEvolutionExperiment Type
# ============================================================================

struct SimpleEvolutionExperiment <: AbstractExperiment
    config::ExperimentConfig
    sim_config::SimConfig
end

# ============================================================================
# Result Extraction Functions
# ============================================================================

"""
    extract_yearly_metrics(results_data::DataFrame)::Dict{Int64, Dict{String, Float64}}

Extract population, sex ratio, and average age by year from exported `*_results.csv`.
Uses `median_age` column as average age, and reconstructs males/females counts
from `population` and `sex_ratio` when available.
Returns dict with year as key and dict of metrics as value.
"""
function extract_yearly_metrics(results_data::DataFrame)::Dict{Int64, Dict{String, Float64}}
    results = Dict{Int64, Dict{String, Float64}}()

    for row in eachrow(results_data)
        year = Int64(row.year)
        population = Float64(row.population)
        sex_ratio = hasproperty(row, :sex_ratio) ? Float64(row.sex_ratio) : 0.0
        avg_age = hasproperty(row, :median_age) ? Float64(row.median_age) : 0.0

        # Reconstruct males/females from sex_ratio = males / females
        males = 0.0
        females = 0.0
        if sex_ratio > 0
            females = population / (1.0 + sex_ratio)
            males = population - females
        else
            # If sex_ratio not available or zero, assume all population is females (fallback)
            females = population
            males = 0.0
        end

        results[year] = Dict(
            "population" => population,
            "sex_ratio" => sex_ratio,
            "avg_age" => avg_age,
            "males" => males,
            "females" => females
        )
    end

    return results
end

"""
    find_latest_export_files(results_base_dir::String)::Tuple{String, String, String, String}

Find the latest timestamped export files in results/ directory.
Return tuple (results_csv, age_csv, timeline_csv, config_json).
"""
function find_latest_export_files(results_base_dir::String)::Tuple{String, String, String, String}
    # List all files in results_base_dir and pick most recently modified results file
    files = readdir(results_base_dir)
    results_files = filter(f -> endswith(f, "_results.csv"), files)

    if isempty(results_files)
        error("No export files found in $results_base_dir")
    end

    # Choose the file with the latest modification time (robust to filename formats)
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

"""
    run(exp::SimpleEvolutionExperiment)::Bool

Execute the simple evolution experiment:
1. Run num_simulations independent simulations with same parameters
2. Extract metrics by year for each simulation
3. Aggregate across simulations: mean and standard error per year
4. Save results to TIMESTAMP_results.csv and TIMESTAMP_plot.csv
5. Save configuration and description JSONs
"""
function run(exp::SimpleEvolutionExperiment)::Bool
    println("=" ^ 70)
    println("Starting Simple Evolution Experiment")
    println("=" ^ 70)
    
    config = exp.config
    sim_config = exp.sim_config
    
    # Determine base seed and report
    if config.seed !== nothing
        base_seed = config.seed
    else
        base_seed = rand(1:10^9)
    end
    println("Base seed for simulations: $base_seed (will increment per run)")
    
    # Ensure output directory exists
    aggregated_dir = ensure_aggregated_results_dir()
    timestamp = generate_timestamp()
    
    # println("Running $(config.num_simulations) simulations...")
    # println("Simulation years: $(sim_config.simulation_years)")
    # println()
    
    # Store yearly metrics from all simulations
    all_sim_metrics = Vector{Dict{Int64, Dict{String, Float64}}}()
    
    # Run simulations
    for sim_idx in 1:config.num_simulations
        print("Simulation $sim_idx/$(config.num_simulations)...\r")

        # Prepare per-simulation seed (auto-increment)
        sim_seed = base_seed + (sim_idx - 1)
        sim_cfg = modify_sim_config(sim_config, "random_seed", sim_seed)

        # Run simulation with export
        run_simulation(sim_cfg; export_results=true)

        # Find and load the latest exported results CSV
        results_dir = PopulationSimulator.PopulationManager.ensure_results_dir()
        (results_csv, _, _, _) = find_latest_export_files(results_dir)

        results_df = CSV.read(results_csv, DataFrame)
        yearly_metrics = extract_yearly_metrics(results_df)
        
        push!(all_sim_metrics, yearly_metrics)
    end
    
    println()
    println("Aggregating results across simulations...")
    
    # Aggregate metrics by year
    # Get all years present across simulations
    all_years = Set{Int64}()
    for metrics_dict in all_sim_metrics
        union!(all_years, keys(metrics_dict))
    end
    all_years = sort(collect(all_years))
    
    # Calculate statistics for each year
    aggregated_results = DataFrame(
        year = Int64[],
        population_mean = Float64[],
        population_se = Float64[],
        sex_ratio_mean = Float64[],
        sex_ratio_se = Float64[],
        avg_age_mean = Float64[],
        avg_age_se = Float64[],
        males_mean = Float64[],
        females_mean = Float64[]
    )
    
    for year in all_years
        pop_values = Float64[]
        sex_ratio_values = Float64[]
        avg_age_values = Float64[]
        males_values = Float64[]
        females_values = Float64[]
        
        for metrics_dict in all_sim_metrics
            if haskey(metrics_dict, year)
                push!(pop_values, metrics_dict[year]["population"])
                push!(sex_ratio_values, metrics_dict[year]["sex_ratio"])
                push!(avg_age_values, metrics_dict[year]["avg_age"])
                push!(males_values, metrics_dict[year]["males"])
                push!(females_values, metrics_dict[year]["females"])
            end
        end
        
        pop_mean, _, pop_se = calculate_stats(pop_values)
        sr_mean, _, sr_se = calculate_stats(sex_ratio_values)
        age_mean, _, age_se = calculate_stats(avg_age_values)
        males_mean, _, _ = calculate_stats(males_values)
        females_mean, _, _ = calculate_stats(females_values)
        
        push!(aggregated_results, (
            year, pop_mean, pop_se, sr_mean, sr_se, age_mean, age_se, males_mean, females_mean
        ))
    end
    
    # Save RESULTS CSV (includes all useful metrics)
    results_filepath = joinpath(aggregated_dir, "simple_$(timestamp)_results.csv")
    CSV.write(results_filepath, aggregated_results)
    println("✓ Saved results to: $results_filepath")
    
    # # Save PLOT CSV (only columns needed for plotting)
    # plot_df = select(aggregated_results, 
    #     :year, :population_mean, :population_se, 
    #     :sex_ratio_mean, :sex_ratio_se, 
    #     :avg_age_mean, :avg_age_se
    # )
    # plot_filepath = joinpath(aggregated_dir, "$(timestamp)_plot.csv")
    # CSV.write(plot_filepath, plot_df)
    # println("✓ Saved plot data to: $plot_filepath")
    
    # Save CONFIG JSON
    metadata = ExperimentMetadata(
        timestamp,
        config,
        sim_config,
        Dict("experiment_type" => "simple_evolution")
    )
    config_filepath = joinpath(aggregated_dir, "simple_$(timestamp)_config.json")
    save_config_json(metadata, config_filepath)
    println("✓ Saved config to: $config_filepath")
    
    # Save DESCRIPTION JSON (for Python plotter)
    description = Dict(
        "type" => "simple_evolution",
        "experiment_name" => config.name,
        "experiment_description" => config.description,
        "parameters" => Dict(
            "num_simulations" => config.num_simulations,
            "simulation_years" => sim_config.simulation_years,
            "population_size" => sim_config.population_size
        ),
        "axes" => Dict(
            "x" => "year",
            "y_columns" => ["population_mean", "sex_ratio_mean", "avg_age_mean"],
            "error_columns" => ["population_se", "sex_ratio_se", "avg_age_se"]
        ),
        "data_file" => "simple_$(timestamp)_results.csv"
    )
    desc_filepath = joinpath(aggregated_dir, "simple_$(timestamp)_description.json")
    save_description_json(description, desc_filepath)
    println("✓ Saved description to: $desc_filepath")
    
    println()
    println("=" ^ 70)
    println("Simple Evolution Experiment completed successfully!")
    println("=" ^ 70)
    
    return true
end
