"""
    PopulationManager

Management of population state, statistics aggregation, and data export.
"""

module PopulationManager

using CSV, DataFrames, ..PersonModule, ..ProbabilityTables, ..SimulatorConfig

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
        0, 0, 0, 0
    )
    
    for _ in 1:config.population_size
        age_days = Int64(floor(ProbabilityTables.sample_initial_age() * 365))
        desired_children = ProbabilityTables.sample_initial_desired_children()
        
        sex = ProbabilityTables.sample_sex() == 1 ? PersonModule.male : PersonModule.female

        person = PersonModule.Person(
            pop.next_id,
            age_days,
            sex,
            desired_children
        )
        
        pop.people[pop.next_id] = person
        pop.next_id += 1
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
function aggregate_annual_statistics(pop::Population, year::Int64)::AnnualStatistics
    n = get_population_size(pop)
    
    # Calculate ages and medians
    ages_years = [get_age_years(person) for person in values(pop.people)]
    ages_sorted = sort(ages_years)
    median_age = ages_sorted[div(n, 2) + 1]
    mean_age = sum(ages_sorted) / n
    standard_age_error = 0.0 #TODO
    
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
        standard_age_error,
        sex_ratio
    )
    
    # Reset counters for next year
    pop.year_births = 0
    pop.year_deaths = 0
    pop.year_marriages = 0
    pop.year_separations = 0
    
    push!(pop.annual_stats, stats)
    
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
    # This is called after simulation ends; reconstruct from snapshots
    # Generates decadal age distributions
    dfs = []
    
    for year in 0:10:config.simulation_years
        if year < length(pop.annual_stats)
            df_year = build_age_distribution(pop, year)
            push!(dfs, df_year)
        end
    end
    
    if !isempty(dfs)
        result_df = vcat(dfs...)
        CSV.write(output_path, result_df)
        println("Age distribution exported to: $(output_path)")
    else
        println("No age distribution data available")
    end
end

end # module
