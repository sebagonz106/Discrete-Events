"""
    base.jl

Base types and utilities for experiments.
Defines the abstract experiment interface and common helper functions.
"""

using Dates
using DataFrames
using CSV
using Statistics

# ============================================================================
# Abstract Types
# ============================================================================

abstract type AbstractExperiment end

# ============================================================================
# Configuration Types
# ============================================================================

"""
    ExperimentConfig

Stores common configuration for experiments.
"""
struct ExperimentConfig
    name::String
    num_simulations::Int64
    seed::Union{Int64, Nothing}
    description::String
end

"""
    ExperimentMetadata

Stores metadata including timestamp, configuration, and sim parameters.
"""
struct ExperimentMetadata
    timestamp::String
    config::ExperimentConfig
    sim_config::SimConfig
    extra_params::Dict{String, Any}
end

# ============================================================================
# Helper Functions
# ============================================================================

"""
    generate_timestamp()::String

Generate a timestamp string in format YYYYMMDD_HHMMSS.
"""
function generate_timestamp()::String
    Dates.format(now(), "yyyymmdd_HHMMSS")
end

"""
    ensure_aggregated_results_dir()::String

Ensure aggregated-results directory exists. Return its path.
"""
function ensure_aggregated_results_dir()::String
    results_dir = joinpath(pwd(), "aggregated-results")
    if !isdir(results_dir)
        mkdir(results_dir)
    end
    return results_dir
end

"""
    save_config_json(metadata::ExperimentMetadata, filepath::String)

Save experiment configuration to JSON file (simple format without external JSON package).
"""
function save_config_json(metadata::ExperimentMetadata, filepath::String)
    config = metadata.config
    sim_config = metadata.sim_config
    
    # Build JSON manually (to avoid external dependencies)
    json_lines = String[]
    push!(json_lines, "{")
    push!(json_lines, "  \"timestamp\": \"$(metadata.timestamp)\",")
    push!(json_lines, "  \"experiment_name\": \"$(config.name)\",")
    push!(json_lines, "  \"description\": \"$(config.description)\",")
    push!(json_lines, "  \"num_simulations\": $(config.num_simulations),")
    push!(json_lines, "  \"seed\": $(config.seed === nothing ? "null" : config.seed),")
    push!(json_lines, "  \"simulation_config\": {")
    push!(json_lines, "    \"population_size\": $(sim_config.population_size),")
    push!(json_lines, "    \"male_population\": $(sim_config.male_population),")
    push!(json_lines, "    \"fertility_age_min\": $(sim_config.fertility_age_min),")
    push!(json_lines, "    \"fertility_age_max\": $(sim_config.fertility_age_max),")
    push!(json_lines, "    \"simulation_years\": $(sim_config.simulation_years),")
    push!(json_lines, "    \"age_max\": $(sim_config.age_max),")
    push!(json_lines, "    \"age_distribution_interval\": $(sim_config.age_distribution_interval)")
    push!(json_lines, "  },")
    push!(json_lines, "  \"extra_parameters\": {")
    
    extra_items = collect(metadata.extra_params)
    for (i, (key, value)) in enumerate(extra_items)
        comma = i < length(extra_items) ? "," : ""
        if isa(value, String)
            push!(json_lines, "    \"$key\": \"$value\"$comma")
        elseif isa(value, Vector)
            str_vals = join(["\"$v\"" for v in value], ", ")
            push!(json_lines, "    \"$key\": [$str_vals]$comma")
        else
            push!(json_lines, "    \"$key\": $value$comma")
        end
    end
    
    push!(json_lines, "  }")
    push!(json_lines, "}")
    
    open(filepath, "w") do f
        write(f, join(json_lines, "\n"))
    end
end

"""
    save_description_json(description::Dict, filepath::String)

Save experiment description for Python plotter.
"""
function save_description_json(description::Dict, filepath::String)
    json_lines = String[]
    push!(json_lines, "{")
    
    desc_items = collect(description)
    for (i, (key, value)) in enumerate(desc_items)
        comma = i < length(desc_items) ? "," : ""
        if isa(value, String)
            push!(json_lines, "  \"$key\": \"$value\"$comma")
        elseif isa(value, Dict)
            # Nested dict
            nested_items = collect(value)
            nested_strs = String[]
            for (nkey, nval) in nested_items
                if isa(nval, String)
                    push!(nested_strs, "    \"$nkey\": \"$nval\"")
                else
                    push!(nested_strs, "    \"$nkey\": $nval")
                end
            end
            nested_json = join(nested_strs, ",\n")
            push!(json_lines, "  \"$key\": {\n$nested_json\n  }$comma")
        else
            push!(json_lines, "  \"$key\": $value$comma")
        end
    end
    
    push!(json_lines, "}")
    
    open(filepath, "w") do f
        write(f, join(json_lines, "\n"))
    end
end

"""
    calculate_stats(values::Vector{Float64})::Tuple{Float64, Float64, Float64}

Calculate mean, std, and standard error.
Return (mean, std, se).
"""
function calculate_stats(values::Vector{Float64})::Tuple{Float64, Float64, Float64}
    n = length(values)
    if n == 0
        return (0.0, 0.0, 0.0)
    elseif n == 1
        return (values[1], 0.0, 0.0)
    end
    
    m = mean(values)
    s = std(values; corrected=true)
    se = s / sqrt(n)
    
    return (m, s, se)
end

"""
    modify_sim_config(base_config::SimConfig, param_name::String, param_value)::SimConfig

Create a copy of sim_config with one parameter modified.
"""
function modify_sim_config(base_config::SimConfig, param_name::String, param_value)::SimConfig
    if param_name == "population_size"
        return SimConfig(
            population_size=param_value,
            male_population=base_config.male_population,
            fertility_age_min=base_config.fertility_age_min,
            fertility_age_max=base_config.fertility_age_max,
            simulation_years=base_config.simulation_years,
            age_max=base_config.age_max,
            age_distribution_interval=base_config.age_distribution_interval
        )
    elseif param_name == "male_population"
        return SimConfig(
            population_size=base_config.population_size,
            male_population=param_value,
            fertility_age_min=base_config.fertility_age_min,
            fertility_age_max=base_config.fertility_age_max,
            simulation_years=base_config.simulation_years,
            age_max=base_config.age_max,
            age_distribution_interval=base_config.age_distribution_interval
        )
    elseif param_name == "fertility_age_min"
        return SimConfig(
            population_size=base_config.population_size,
            male_population=base_config.male_population,
            fertility_age_min=param_value,
            fertility_age_max=base_config.fertility_age_max,
            simulation_years=base_config.simulation_years,
            age_max=base_config.age_max,
            age_distribution_interval=base_config.age_distribution_interval
        )
    elseif param_name == "fertility_age_max"
        return SimConfig(
            population_size=base_config.population_size,
            male_population=base_config.male_population,
            fertility_age_min=base_config.fertility_age_min,
            fertility_age_max=param_value,
            simulation_years=base_config.simulation_years,
            age_max=base_config.age_max,
            age_distribution_interval=base_config.age_distribution_interval
        )
    elseif param_name == "age_max"
        return SimConfig(
            population_size=base_config.population_size,
            male_population=base_config.male_population,
            fertility_age_min=base_config.fertility_age_min,
            fertility_age_max=base_config.fertility_age_max,
            simulation_years=base_config.simulation_years,
            age_max=param_value,
            age_distribution_interval=base_config.age_distribution_interval
        )
    elseif param_name == "random_seed"
        return SimConfig(
            population_size=base_config.population_size,
            male_population=base_config.male_population,
            fertility_age_min=base_config.fertility_age_min,
            fertility_age_max=base_config.fertility_age_max,
            simulation_years=base_config.simulation_years,
            age_max=base_config.age_max,
            age_distribution_interval=base_config.age_distribution_interval,
            random_seed=param_value
        )
    else
        error("Unknown parameter: $param_name")
    end
end

# ============================================================================
# Interface
# ============================================================================

"""
    run(exp::AbstractExperiment)::Bool

Abstract function that concrete experiments must implement.
Return true if successful, false otherwise.
"""
function run(exp::AbstractExperiment)::Bool
    error("Experiment type $(typeof(exp)) must implement run() method")
end
