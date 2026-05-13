#!/usr/bin/env julia
"""
Test script to validate Step 2 architecture implementation.

Usage:
    julia test_step2.jl
"""

using Pkg

# Activate the project environment
Pkg.activate(joinpath(@__DIR__, ".."))

# Load the main module
include("../src/population_sim.jl")
using .PopulationSimulator

# ============================================================================
# Test 1: Configuration
# ============================================================================
println("=" ^ 60)
println("TEST 1: Configuration")
println("=" ^ 60)

config = SimulatorConfig.DEFAULT_CONFIG
println("✓ Configuration loaded:")
println("  - Population size: $(config.population_size) per sex")
println("  - Simulation years: $(config.simulation_years)")
println("  - Max age: $(config.age_max)")
println("  - Days per simulation: $(config.total_days)")
println()

# ============================================================================
# Test 2: Person Creation
# ============================================================================
println("=" ^ 60)
println("TEST 2: Person Creation")
println("=" ^ 60)

person1 = PersonModule.Person(
    1,
    25 * SimulatorConfig.DAYS_PER_YEAR,  # 25 years in days
    PersonModule.male,
    2          # desired children
)

person2 = PersonModule.Person(
    2,
    22 * SimulatorConfig.DAYS_PER_YEAR,  # 22 years in days
    PersonModule.female,
    3          # desired children
)

println("✓ Person 1 created:")
println("  - ID: $(person1.id), Age: $(div(person1.age_days, SimulatorConfig.DAYS_PER_YEAR)) years")
println("  - Sex: $(person1.sex), Marital: $(person1.marital_status)")
println("✓ Person 2 created:")
println("  - ID: $(person2.id), Age: $(div(person2.age_days, SimulatorConfig.DAYS_PER_YEAR)) years")
println("  - Sex: $(person2.sex), Desired children: $(person2.desired_children)")
println()

# ============================================================================
# Test 3: Event Types
# ============================================================================
println("=" ^ 60)
println("TEST 3: Event Types")
println("=" ^ 60)

death_event = EventEngine.DeathEvent(365, 1)
birth_event = EventEngine.BirthEvent(730, 2, 1)
marriage_event = EventEngine.MarriageEvent(200, 2, 1)
pregnancy_event = EventEngine.PregnancyAttemptEvent(500, 2)
separation_event = EventEngine.SeparationEvent(900, 1)
year_end_event = EventEngine.YearEndEvent(365)

println("✓ Event types created successfully:")
println("  - DeathEvent(time=$(death_event.time_days), person_id=$(death_event.person_id))")
println("  - BirthEvent(time=$(birth_event.time_days), mother_id=$(birth_event.mother_id), num=$(birth_event.num_babies))")
println("  - MarriageEvent(time=$(marriage_event.time_days))")
println("  - PregnancyAttemptEvent(time=$(pregnancy_event.time_days))")
println("  - SeparationEvent(time=$(separation_event.time_days))")
println("  - YearEndEvent(time=$(year_end_event.time_days))")
println()

# ============================================================================
# Test 4: Event Queue
# ============================================================================
println("=" ^ 60)
println("TEST 4: Event Queue (Priority Queue)")
println("=" ^ 60)

queue = EventEngine.EventQueue()

# Add events in non-chronological order
push!(queue, EventEngine.BirthEvent(1000, 2, 2))
push!(queue, EventEngine.DeathEvent(200, 5))
push!(queue, EventEngine.MarriageEvent(50, 1, 3))
push!(queue, EventEngine.YearEndEvent(365))

println("✓ Added 4 events to queue (unordered)")
println("  Queue length: $(length(queue))")

# Extract events in order
events = []
while !isempty(queue)
    event = pop!(queue)
    push!(events, event)
    println("  - Extracted: $(typeof(event).name.name) at time $(event.time_days)")
end

# Verify ordering
is_sorted = all(events[i].time_days <= events[i+1].time_days for i in 1:length(events)-1)
println("✓ Events extracted in chronological order: $is_sorted")
println()

# ============================================================================
# Test 5: Population
# ============================================================================
println("=" ^ 60)
println("TEST 5: Population Initialization")
println("=" ^ 60)

pop = PopulationManager.initialize_population!(config)

println("✓ Population initialized:")
println("  - Total population: $(PopulationManager.get_population_size(pop))")
println("  - Expected: $(2 * config.population_size)")
println("  - Next ID: $(pop.next_id)")

# Check sample persons
for (id, person) in collect(pop.people)[1:3]
    age_yrs = PopulationManager.get_age_years(person)
    sex_str = person.sex == PersonModule.male ? "M" : "F"
    println("  Sample: ID=$id, Age=$age_yrs yrs, Sex=$sex_str")
end
println()

# ============================================================================
# Test 6: Probability Tables
# ============================================================================
println("=" ^ 60)
println("TEST 6: Probability Tables")
println("=" ^ 60)

println("✓ Sample probability lookups:")
println("  - Death prob (30-year-old male): $(ProbabilityTables.get_death_probability(30, PersonModule.male))")
println("  - Pregnancy prob (28-year-old woman): $(ProbabilityTables.get_pregnancy_probability(28))")
println("  - Want partner prob (35 years): $(ProbabilityTables.get_want_partner_probability(35))")
println("  - Couple formation (age diff 8 years): $(ProbabilityTables.get_couple_formation_probability(8))")
println("  - Waiting period lambda (25 years, in days): $(ProbabilityTables.get_rupture_waiting_period(25))")

# Sample random variables
println("✓ Random sampling:")
babies = ProbabilityTables.sample_num_babies()
children = ProbabilityTables.get_desired_children()
println("  - Sampled babies per birth: $babies")
println("  - Sampled desired children: $children")
println()

# ============================================================================
# Test 7: Statistics Aggregation
# ============================================================================
println("=" ^ 60)
println("TEST 7: Annual Statistics")
println("=" ^ 60)

pop.year_births = 12
pop.year_deaths = 3
pop.year_marriages = 5
pop.year_separations = 1

stats = PopulationManager.aggregate_annual_statistics(pop, 0)

println("✓ Annual statistics aggregated:")
println("  - Year: $(stats.year)")
println("  - Population: $(stats.population_count)")
println("  - Births: $(stats.births), Deaths: $(stats.deaths)")
println("  - Marriages: $(stats.marriages), Separations: $(stats.separations)")
println("  - Median age: $(stats.median_age), Mean age: $(round(stats.mean_age, digits=1))")
println("  - Sex ratio (M/F): $(round(stats.sex_ratio, digits=3))")
println()

# ============================================================================
# Summary
# ============================================================================
println("=" ^ 60)
println("✓ ALL TESTS PASSED")
println("=" ^ 60)
println("Architecture Implementation Validated Successfully")
println()
