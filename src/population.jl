"""
    PopulationManager

Management of population state, statistics aggregation, and data export.
"""

module PopulationManager

using CSV, DataFrames, Statistics, Dates, ..PersonModule, ..ProbabilityTables, ..SimulatorConfig

export Population, AnnualStatistics, PopulationManager, 
       initialize_population!, get_person, remove_person!, 
       aggregate_annual_statistics, export_results_csv, export_age_distribution_csv

"""
    AnnualStatistics

Aggregated statistics for a single year of simulation.
"""
mutable struct AnnualStatistics
    year::Int64
    population_count::Int64
    births::Int64
    deaths::Int64
    marriages::Int64
    separations::Int64
    median_age::Float64
    mean_age::Float64
    standard_age_error::Float64
    sex_ratio::Float64  # males / females
end

"""
    Population

Holder for population state and statistics.
"""
mutable struct Population
    """Collection of individuals."""
    people::Dict{Int64, PersonModule.Person}
    
    """Next ID to assign."""
    next_id::Int64
    
    """Annual statistics over simulation."""
    annual_stats::Vector{AnnualStatistics}

    """Age distribution snapshots keyed by year."""
    age_snapshots::Dict{Int64, DataFrame}
    
    """Counters for current year."""
    year_births::Int64
    year_deaths::Int64
    year_marriages::Int64
    year_separations::Int64
end

"""
    initialize_population!(config::SimConfig)::Population
    
Create initial population with random sex ratio and ages.

# Arguments
- `config::SimConfig`: Configuration with population size

# Returns
- `Population`: Initialized population object
"""
function initialize_population!(config::SimConfig)::Population
    pop = Population(
        Dict{Int64, PersonModule.Person}(),
        1,
        Vector{AnnualStatistics}(),
        Dict{Int64, DataFrame}(),
        0, 0, 0, 0
    )

    if config.male_population < 0 || config.male_population > config.population_size # Use birth sex distribution
        for _ in 1:config.population_size
            age_days = Int64(floor(ProbabilityTables.sample_initial_age() * SimulatorConfig.DAYS_PER_YEAR))
            desired_children = ProbabilityTables.sample_desired_children()

            sex = ProbabilityTables.sample_sex()

            person = PersonModule.Person(
                pop.next_id,
                age_days,
                sex,
                desired_children
            )

            pop.people[pop.next_id] = person
            pop.next_id += 1
        end
    else # Replicated logic for faster initialization
        function increase_population(count::Int64, sex::PersonModule.Sex)
            for _ in 1:count
                age_days = Int64(floor(ProbabilityTables.sample_initial_age() * SimulatorConfig.DAYS_PER_YEAR))
                desired_children = ProbabilityTables.sample_desired_children()

                person = PersonModule.Person(
                    pop.next_id,
                    age_days,
                    sex,
                    desired_children
                )

                pop.people[pop.next_id] = person
                pop.next_id += 1
            end
        end

        increase_population(config.male_population, PersonModule.male)
        increase_population(config.population_size - config.male_population, PersonModule.female)
    end

    return pop
end

"""
    get_person(pop::Population, person_id::Int64)::Union{PersonModule.Person, Nothing}
    
Retrieve person by ID; nothing if not found.
"""
function get_person(pop::Population, person_id::Int64)::Union{PersonModule.Person, Nothing}
    get(pop.people, person_id, nothing)
end

"""
    remove_person!(pop::Population, person_id::Int64)::Nothing
    
Remove person from population.
"""
function remove_person!(pop::Population, person_id::Int64)::Nothing
    delete!(pop.people, person_id)
    nothing
end

"""
    get_population_size(pop::Population)::Int64
    
Return current population size.
"""
function get_population_size(pop::Population)::Int64
    length(pop.people)
end

"""
    get_age_years(person::PersonModule.Person)::Int64
    
Convert person's age from days to complete years.
"""
function get_age_years(person::PersonModule.Person)::Int64
    div(person.age_days, SimulatorConfig.DAYS_PER_YEAR)
end

"""
    aggregate_annual_statistics(pop::Population, year::Int64)::AnnualStatistics
    
Calculate statistics for the given year.
"""
function aggregate_annual_statistics(pop::Population, year::Int64,
                                     config::SimConfig=SimulatorConfig.DEFAULT_CONFIG)::AnnualStatistics
    n = get_population_size(pop)
    
    # Calculate ages and medians
    ages_years = [get_age_years(person) for person in values(pop.people)]
    ages_sorted = sort(ages_years)
    median_age = ages_sorted[div(n, 2) + 1]
    mean_age = sum(ages_sorted) / n
    std_age_error = std(ages_sorted)
    
    # Count by sex
    males = sum(p.sex == PersonModule.male for p in values(pop.people))
    females = n - males
    sex_ratio = females > 0 ? males / females : 0.0
    
    stats = AnnualStatistics(
        year,
        n,
        pop.year_births,
        pop.year_deaths,
        pop.year_marriages,
        pop.year_separations,
        Float64(median_age),
        mean_age,
        std_age_error,
        sex_ratio
    )
    
    # Reset counters for next year
    pop.year_births = 0
    pop.year_deaths = 0
    pop.year_marriages = 0
    pop.year_separations = 0
    
    push!(pop.annual_stats, stats)

    # Persist age-distribution snapshots only at configured interval.
    if config.age_distribution_interval > 0 && mod(year, config.age_distribution_interval) == 0
        pop.age_snapshots[year] = build_age_distribution(pop, year)
    end
    
    return stats
end

"""
    build_age_distribution(pop::Population, year::Int64)::DataFrame
    
Create age distribution snapshot for given year.

# Returns
- `DataFrame`: Columns: year, age_range, males, females
"""
function build_age_distribution(pop::Population, year::Int64)::DataFrame
    age_ranges = ["0-4", "5-9", "10-14", "15-19", "20-24", "25-29", 
                  "30-34", "35-39", "40-44", "45-49", "50-54", "55-59",
                  "60-64", "65-69", "70-74", "75-79", "80-84", "85-89", "90-99", "100+"]
    
    age_bins = [
        (0, 5), (5, 10), (10, 15), (15, 20), (20, 25), (25, 30),
        (30, 35), (35, 40), (40, 45), (45, 50), (50, 55), (55, 60),
        (60, 65), (65, 70), (70, 75), (75, 80), (80, 85), (85, 90), (90, 100), (100, 150)
    ]
    
    rows = []
    for (i, (age_min, age_max)) in enumerate(age_bins)
        males = sum(
            p.sex == PersonModule.male && age_min <= get_age_years(p) < age_max
            for p in values(pop.people)
        )
        females = sum(
            p.sex == PersonModule.female && age_min <= get_age_years(p) < age_max
            for p in values(pop.people)
        )
        
        push!(rows, (year, age_ranges[i], males, females))
    end
    
    return DataFrame(year=getindex.(rows, 1), 
                     age_range=getindex.(rows, 2),
                     males=getindex.(rows, 3),
                     females=getindex.(rows, 4))
end

"""
    export_results_csv(pop::Population, output_path::String)::Nothing
    
Export annual statistics to CSV.
"""
function export_results_csv(pop::Population, output_path::String)::Nothing
    df = DataFrame(
        year=Int64[s.year for s in pop.annual_stats],
        population=Int64[s.population_count for s in pop.annual_stats],
        births=Int64[s.births for s in pop.annual_stats],
        deaths=Int64[s.deaths for s in pop.annual_stats],
        marriages=Int64[s.marriages for s in pop.annual_stats],
        divorces=Int64[s.separations for s in pop.annual_stats],
        median_age=Float64[s.median_age for s in pop.annual_stats],
        sex_ratio=Float64[s.sex_ratio for s in pop.annual_stats]
    )
    
    CSV.write(output_path, df)
    println("✓ Results exported to: $(output_path)")
end

"""
    export_age_distribution_csv(pop::Population, config::SimConfig,
                                output_path::String)::Nothing

Export age distributions (every 10 years) to CSV.
"""
function export_age_distribution_csv(pop::Population, config::SimConfig,
                                     output_path::String)::Nothing
    # Uses snapshots captured during simulation at configured interval.
    dfs = DataFrame[]

    interval = config.age_distribution_interval
    years = sort(collect(keys(pop.age_snapshots)))
    selected_years = [y for y in years if y >= 0 && y <= config.simulation_years &&
                                     (interval <= 0 || mod(y, interval) == 0)]

    for year in selected_years
        push!(dfs, pop.age_snapshots[year])
    end
    
    if !isempty(dfs)
        result_df = vcat(dfs...)
        CSV.write(output_path, result_df)
        println("Age distribution exported to: $(output_path)")
    else
        println("No age distribution data available")
    end
end

"""
    ensure_results_dir()::String
    
Ensure `results/` folder exists. Returns path to results directory.
"""
function ensure_results_dir()::String
    results_dir = joinpath(@__DIR__, "..", "individual-results")
    if !isdir(results_dir)
        mkdir(results_dir)
    end
    return results_dir
end

"""
    generate_timestamp()::String
    
Generate timestamp string in format YYYYMMDD_HHMMSS.
"""
function generate_timestamp()::String
    return Dates.format(now(), "yyyymmdd_HHMMSS")
end

"""
    export_config_json(config::SimConfig, output_path::String)::Nothing

Write a minimal JSON file containing the selected simulation configuration.
"""
function export_config_json(config::SimConfig, output_path::String)::Nothing
    male_population_text = config.male_population < 0 ? "" : "\n\t\"male_population\": $(config.male_population),"
    json_text = """
{
  \"population_size\": $(config.population_size),$male_population_text
  \"simulation_years\": $(config.simulation_years),
  \"total_days\": $(config.total_days),
  \"age_max\": $(config.age_max),
  \"fertility_age_min\": $(config.fertility_age_min),
  \"fertility_age_max\": $(config.fertility_age_max),
  \"pair_bond_age_min\": $(config.pair_bond_age_min),
  \"age_distribution_interval\": $(config.age_distribution_interval),
  \"validate_consistency\": $(config.validate_consistency ? "true" : "false"),
  \"verbose_logging\": $(config.verbose_logging ? "true" : "false"),
  \"random_seed\": $(config.random_seed)
}
"""

    open(output_path, "w") do io
        write(io, json_text)
    end

    println("Config exported to: $(output_path)")
end

"""
    export_results_with_timestamp(pop::Population, config::SimConfig)::Tuple{String, String, String}
    
Export results, age distribution, and timeline with automatic timestamping.
Returns tuple of (results_csv_path, age_csv_path, timeline_csv_path).
"""
function export_result_files(pop::Population, config::SimConfig, verbose::Bool=false,
                            timeline_logs::Vector{String} = String[])::Tuple{String, String, String, String}
    results_dir = ensure_results_dir()
    timestamp = generate_timestamp()
    
    # Construct file paths
    results_file = joinpath(results_dir, "$(timestamp)_results.csv")
    age_file = joinpath(results_dir, "$(timestamp)_population_age.csv")
    timeline_file = joinpath(results_dir, "$(timestamp)_timeline.csv")
    config_file = joinpath(results_dir, "$(timestamp)_config.json")
    
    # Export results
    export_results_csv(pop, results_file)
    
    # Export age distribution
    export_age_distribution_csv(pop, config, age_file)

    # Export configuration snapshot
    export_config_json(config, config_file)
    
    # Export timeline (if logs provided)
    if !isempty(timeline_logs)
        df_timeline = DataFrame(
            log_entry=timeline_logs
        )
        CSV.write(timeline_file, df_timeline)
        println("Timeline exported to: $(timeline_file)")
    end
    
    println("\nAll results exported to: $results_dir/")
    println("  - Results: $(timestamp)_results.csv")
    println("  - Age distribution: $(timestamp)_population_age.csv")
    println("  - Config: $(timestamp)_config.json")
    if !isempty(timeline_logs)
        println("  - Timeline: $(timestamp)_timeline.csv")
    end
    
    return (results_file, age_file, timeline_file, config_file)
end

end # module
