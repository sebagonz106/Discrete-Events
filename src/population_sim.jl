"""
    PopulationSimulator

Main module for discrete-event population simulator.

# Overview
This package simulates 100 years of population evolution using discrete event simulation (DES).
The system models vital events (births, deaths, marriages, separations) with age- and sex-dependent
probabilities derived from demographic literature.

# Architecture
- Julia: High-performance DES engine
- Python: Statistical analysis and visualization
- Communication: CSV data interchange

# Usage
```julia
using PopulationSimulator

config = PopulationSimulator.SimulatorConfig.SimConfig()
state = PopulationSimulator.SimulatorEngine.run_simulation(config)
```
"""

module PopulationSimulator

# Include sub-modules in dependency order
include("simulator_config.jl")
include("random_generators.jl")
include("person.jl")
include("event_engine.jl")
include("probability_tables.jl")
include("population.jl")

# Import sub-modules
using .SimulatorConfig, .RandomGenerators, .PersonModule, .EventEngine, 
      .ProbabilityTables, .PopulationManager

# ============================================================================
# SIMULATOR ENGINE MODULE
# ============================================================================

module SimulatorEngine

using Random, DataStructures, ..SimulatorConfig, ..RandomGenerators, 
      ..PersonModule, ..EventEngine, ..ProbabilityTables, ..PopulationManager

export SimulationState, initialize_simulation, run_simulation, Logger

"""
    Logger

Simple logging system that can be disabled for production.
"""
mutable struct Logger
    enabled::Bool
    year_buffer::Vector{String}
    
    function Logger(enabled::Bool=false)
        new(enabled, String[])
    end
end

function log_event(logger::Logger, msg::String)::Nothing
    if logger.enabled
        push!(logger.year_buffer, msg)
    end
end

function flush_logs(logger::Logger, year::Int64)::Nothing
    if logger.enabled && !isempty(logger.year_buffer)
        println("╔════════════════════════════════════════╗")
        println("║ YEAR $year ║")
        println("╚════════════════════════════════════════╝")
        for msg in logger.year_buffer
            println(msg)
        end
        empty!(logger.year_buffer)
    end
end

"""
    SimulationState

Holds all state needed for the simulation.
"""
mutable struct SimulationState
    config::SimConfig
    current_time_days::Int64          # Current simulation time in days
    current_year::Int64               # Current year
    population::PopulationManager.Population
    event_queue::EventEngine.EventQueue
    
    # Annual counters
    counters_births::Int64
    counters_deaths::Int64
    counters_marriages::Int64
    counters_separations::Int64
    
    logger::Logger
end

function _get_current_year_ending(current_day::Int32)::Int32
    div(current_day, SimulatorConfig.DAYS_PER_YEAR) + SimulatorConfig.DAYS_PER_YEAR
end

function _get_current_year_remainig_days(current::Int32)::Int32
    _get_current_year_ending(current) - current
end

function _get_current_year_remainig_months(current::Int32)::Int32
    div(_get_current_year_remainig_days(current), SimulatorConfig.DAYS_PER_MONTH)
end

"""
    initialize_simulation(config::SimConfig)::SimulationState

Initialize simulation state with configuration and initial population.
"""
function initialize_simulation(config::SimConfig)::SimulationState
    Random.seed!(config.random_seed)
    
    # Initialize population
    pop = PopulationManager.initialize_population!(config)
    
    # Create event queue
    queue = EventEngine.EventQueue()
    
    # Generate YearEndEvent for each year
    for year in 0:config.simulation_years
        t = year * SimulatorConfig.DAYS_PER_YEAR
        if t <= config.total_days
            push!(queue.heap, EventEngine.YearEndEvent(t))
        end
    end
    
    state = SimulationState(
        config,
        0,
        0,
        pop,
        queue,
        0, 0, 0, 0,
        Logger(config.verbose_logging)
    )
    
    return state
end

"""
    run_simulation(config::SimConfig)::SimulationState

Run complete simulation with given configuration.
"""
function run_simulation(config::SimConfig)::SimulationState
    state = initialize_simulation(config)
    main_loop!(state)
    return state
end

"""
    main_loop!(state::SimulationState)::Nothing

Main DES loop: extract event, update time, process.
"""
function main_loop!(state::SimulationState)::Nothing
    while !isempty(state.event_queue.heap) && state.current_time_days <= state.config.total_days
        # Check population hasn't been wiped out
        if isempty(state.population.people)
            println("WARNING: Population extinct at day $(state.current_time_days)")
            break
        end
        
        # Extract next event
        event = pop!(state.event_queue.heap)
        state.current_time_days = event.time_days
        state.current_year = div(event.time_days, SimulatorConfig.DAYS_PER_YEAR)
        
        # Process event by type
        if isa(event, EventEngine.YearEndEvent)
            handle_year_end!(event, state)
        elseif isa(event, EventEngine.DeathEvent)
            handle_death!(event, state)
        elseif isa(event, EventEngine.PregnancyAttemptEvent)
            handle_pregnancy_attempt!(event, state)
        elseif isa(event, EventEngine.BirthEvent)
            handle_birth!(event, state)
        elseif isa(event, EventEngine.SeparationEvent)
            handle_separation!(event, state)
        elseif isa(event, EventEngine.EndWaitingPeriodEvent)
            handle_end_waiting!(event, state)
        elseif isa(event, EventEngine.PartnerSearchEvent)
            handle_partner_search!(event, state)
        end
        
        # Validate if development mode
        if state.config.validate_consistency
            validate_all_persons(state)
        end
    end
end

"""
    handle_year_end!(event::YearEndEvent, state::SimulationState)::Nothing

CENTRAL HUB: Evaluate all vital events for all persons annually.
- Assess deaths for each person
- Assess pregnancies for couples
- Assess couple breakups
- Assess partner searches for singles
"""
function handle_year_end!(event::EventEngine.YearEndEvent, state::SimulationState)::Nothing
    #TODO: Update Annual Statistics (state.pop.annual_stats)

    # Reset annual counters
    state.counters_births = 0
    state.counters_deaths = 0
    state.counters_marriages = 0
    state.counters_separations = 0
    
    # Collect all people
    person_ids = collect(keys(state.population.people))
    
    #TODO: run through women (woman_ids) once deaths are dealt with

    # Evaluate all persons
    for person_id in person_ids
        person = PopulationManager.get_person(state.population, person_id)
        if person === nothing
            continue  # Person already died
        end
        
        # ========================
        # 1. ASSESS DEATH
        # ========================
        age_years = div(person.age_days, SimulatorConfig.DAYS_PER_YEAR)
        is_male = person.sex == PersonModule.male
        death_prob = ProbabilityTables.get_death_probability(age_years, is_male)
        
        if rand() < death_prob
            # Schedule death randomly within this year
            t_death = state.current_time_days + uniformInt(1,365)
            push!(state.event_queue.heap, EventEngine.DeathEvent(t_death, person_id))
        end
        
        # ========================
        # 2. ASSESS PREGNANCY (if woman, paired, fertile, wants more children)
        # ========================
        if person.sex == PersonModule.female && 
           person.partner_id !== nothing &&
           age_years >= state.config.fertility_age_min &&
           age_years < state.config.fertility_age_max &&
           person.num_children < person.desired_children &&
           !person.pregnant
            
            partner = PopulationManager.get_person(state.population, person.partner_id)
            
            #TODO: Refactor so that a PregnancyAttemptEvent occurs monthly in the following year following menstrual cycle    
            
            #TODO: Move following logic to pregnancy attempt event 
            if partner !== nothing && partner.num_children < partner.desired_children
                preg_prob = ProbabilityTables.get_pregnancy_probability(age_years)
                
                if rand() < preg_prob
                    # Will give birth in ~280 days
                    num_babies = ProbabilityTables.sample_num_babies()
                    t_birth = state.current_time_days + SimulatorConfig.GESTATION_PERIOD + uniformInt(-60, 0) # account for early born babies
                    push!(state.event_queue.heap, EventEngine.BirthEvent(t_birth, person_id, num_babies))
                    log_event(state.logger, "  → Pregnancy: Woman #$person_id → birth in ~280 days ($num_babies babies expected)")
                end
            end
        end
        
        # ========================
        # 3. ASSESS BREAKUP (if in couple)
        # ========================
        if person.partner_id !== nothing && person.marital_status == PersonModule.married
            breakup_prob = ProbabilityTables.get_breakup_probability()
            
            if rand() < breakup_prob
                # Schedule separation randomly within this year
                t_sep = state.current_time_days + rand(1:365)
                push!(state.event_queue.heap, EventEngine.SeparationEvent(t_sep, person_id))
                log_event(state.logger, "  → Breakup scheduled: Person #$person_id")
            end
        end
        
        # ========================
        # 4. ASSESS PARTNER SEARCH (if single woman, fertile, wants partner)
        # ========================
        if person.sex == PersonModule.female &&
           person.partner_id === nothing &&
           person.marital_status == PersonModule.single &&
           age_years >= state.config.fertility_age_min &&
           age_years < state.config.fertility_age_max # marriages over this age are insignificant to our population development
            
            p_wants_partner = ProbabilityTables.get_want_partner_probability(age_years)
            
            #TODO: Refactor so a partner search is conducted monthly through PartnerSearchEvent

            if rand() < p_wants_partner
                # Schedule partner search randomly within this year
                t_search = state.current_time_days + rand(1:365)
                push!(state.event_queue.heap, EventEngine.PartnerSearchEvent(t_search, person_id))
                log_event(state.logger, "  → Partner search: Woman #$person_id")
            end
        end
        
        # ========================
        # 5. AGE EVERYONE BY 1 YEAR
        # ========================
        person.age_days += SimulatorConfig.DAYS_PER_YEAR
    end
    
    # Log annual statistics
    log_event(state.logger, "Year $(state.current_year): Pop=$(length(state.population.people)), " *
              "B=$(state.counters_births), D=$(state.counters_deaths), " *
              "M=$(state.counters_marriages), S=$(state.counters_separations)")
    flush_logs(state.logger, state.current_year)
end

"""
    handle_death!(event::DeathEvent, state::SimulationState)::Nothing

Process death: remove from population, handle partner consequences.
"""
function handle_death!(event::EventEngine.DeathEvent, state::SimulationState)::Nothing
    person = PopulationManager.get_person(state.population, event.person_id)
    person === nothing && return
    
    # If has partner, transition partner to widowed + waiting period
    if person.partner_id !== nothing
        partner = PopulationManager.get_person(state.population, person.partner_id)
        
        if partner !== nothing
            partner.partner_id = nothing
            partner.marital_status = PersonModule.widowed
            
            # Generate waiting period (exponential)
            age_partner_years = div(partner.age_days, SimulatorConfig.DAYS_PER_YEAR)
            lambda = ProbabilityTables.get_rupture_waiting_period(age_partner_years)
            t_fin_espera = event.time_days + RandomGenerators.exponential(lambda)
            
            push!(state.event_queue.heap, EventEngine.EndWaitingPeriodEvent(t_fin_espera, partner.id))
            log_event(state.logger, "  → Death: Person #$(event.person_id), partner #$(partner.id) begins waiting")
        end
    end
    
    # Remove from population
    delete!(state.population.people, event.person_id)
    state.counters_deaths += 1
    log_event(state.logger, "  → Death: Person #$(event.person_id) (age $(div(person.age_days, 365)))")
end

"""
    handle_pregnancy_attempt!(event::PregnancyAttemptEvent, state::SimulationState)::Nothing

Process pregnancy attempt: Checks if a pregnancy is achieved and schedules a birth.
"""
function handle_pregnancy_attempt!(event::EventEngine.PregnancyAttemptEvent, state::SimulationState)::Nothing
    #TODO: Implement
end

"""
    handle_birth!(event::BirthEvent, state::SimulationState)::Nothing

Process birth: create new individuals, update parents.
"""
function handle_birth!(event::EventEngine.BirthEvent, state::SimulationState)::Nothing
    mother = PopulationManager.get_person(state.population, event.mother_id)
    if mother === nothing
        return
    end

    early_deaths = 0
    
    for _ in 1:event.num_babies
        new_id = state.population.next_id
        sex = ProbabilityTables.sample_sex() == 1 ? PersonModule.male : PersonModule.female
        
        baby = PersonModule.Person(
            new_id,
            0,  # Age 0 days
            sex,
            ProbabilityTables.sample_desired_children()
        )
        
        state.population.people[new_id] = baby
        state.population.next_id += 1
        
        # Checks early death
        is_male = sex == PersonModule.male
        death_prob = ProbabilityTables.get_death_probability(0, is_male)
        if rand() < death_prob
            t_death = RandomGenerators.uniformInt(state.current_time_days, 
                                                  _get_current_year_ending(state.current_time_days))
            push!(state.event_queue.heap, EventEngine.DeathEvent(t_death, new_id))
            early_deaths += 1
        end
    end
    
    mother.num_children += event.num_babies - early_deaths
    
    if mother.partner_id !== nothing
        partner = PopulationManager.get_person(state.population, mother.partner_id)
        if partner !== nothing
            partner.num_children += event.num_babies - early_deaths
        end
    end
    
    state.counters_births += event.num_babies # Births are accounted for
    log_event(state.logger, "  → Birth: $(event.num_babies) babies born to mother #$(event.mother_id)")
end

"""
    handle_separation!(event::SeparationEvent, state::SimulationState)::Nothing

Process separation/breakup: dissolve couple, start waiting period.
"""
function handle_separation!(event::EventEngine.SeparationEvent, state::SimulationState)::Nothing
    person = PopulationManager.get_person(state.population, event.person_id)
    if person === nothing 
        return # Person is dead
    end

    if person.partner_id === nothing
        return  # Not in couple
    end
    
    partner = PopulationManager.get_person(state.population, person.partner_id)

    if partner === nothing
        # Partner is dead
        person.partner_id = nothing
        peerson.marital_status = PersonModule.widowed
    else
        # Dissolve couple
        person.partner_id = partner.partner_id = nothing
        person.marital_status = partner.marital_status = PersonModule.divorced
    end
    
    state.counters_separations += 1
    
    # Generate waiting period for both (exponential distribution)
    for p in [person, partner]
        if p !== nothing
            age_years = div(p.age_days, SimulatorConfig.DAYS_PER_YEAR)
            lambda = ProbabilityTables.get_rupture_waiting_period(age_years)
            t_fin_espera = event.time_days + RandomGenerators.exponential(lambda)
            
            push!(state.event_queue.heap, EventEngine.EndWaitingPeriodEvent(t_fin_espera, p.id))
        end
    end
    
    log_event(state.logger, "  → Separation: #$(event.person_id) and #$(person.partner_id)")
end

"""
    handle_end_waiting!(event::EndWaitingPeriodEvent, state::SimulationState)::Nothing

Process end of waiting period: transition from divorced/widowed to single.
"""
function handle_end_waiting!(event::EventEngine.EndWaitingPeriodEvent, state::SimulationState)::Nothing
    person = PopulationManager.get_person(state.population, event.person_id)
    if person === nothing
        return
    end
    
    person.marital_status = PersonModule.single

    #TODO: Begin looking for a couple once a month for the remaining months in the current year

    log_event(state.logger, "  → End waiting: Person #$(event.person_id) available for partnership")
end

"""
    handle_partner_search!(event::PartnerSearchEvent, state::SimulationState)::Nothing

Process partner search: find compatible partner, form couple if successful.
Uses O(n) filtering + O(m) search instead of O(n²).
"""
function handle_partner_search!(event::EventEngine.PartnerSearchEvent, state::SimulationState)::Nothing
    person = PopulationManager.get_person(state.population, event.person_id)
    if person === nothing
        return
    end
    if person.partner_id !== nothing
        return  # Already paired
    end
    
    # Filter available partner once (O(n))
    available_partners = [p for p in values(state.population.people)
                     if p.sex != person.sex &&
                        p.partner_id === nothing &&
                        div(p.age_days, SimulatorConfig.DAYS_PER_YEAR) >= state.config.pair_bond_age_min &&
                        p.marital_status == PersonModule.single]
    
    if isempty(available_partners)
        return  # No available partners
    end
    
    # Search through available men
    for candidate in available_partners
        person_age = div(person.age_days, SimulatorConfig.DAYS_PER_YEAR)
        candidate_age = div(candidate.age_days, SimulatorConfig.DAYS_PER_YEAR)
        
        # Both want partner?
        p_person_wants = ProbabilityTables.get_want_partner_probability(person_age)
        p_candidate_wants = ProbabilityTables.get_want_partner_probability(candidate_age)
        
        if rand() < p_person_wants && rand() < p_candidate_wants
            # Age compatibility?
            age_diff = abs(person_age - candidate_age)
            p_compatible = ProbabilityTables.get_couple_formation_probability(age_diff)
            
            if rand() < p_compatible
                # Form couple
                person.partner_id = candidate.id
                candidate.partner_id = person.id
                person.marital_status = candidate.marital_status = PersonModule.married
                
                state.counters_marriages += 1
                log_event(state.logger, "  → Marriage: #$(person.id) and #$(candidate.id)")
                return  # Couple formed, exit
            end
        end
    end
end

"""
    validate_all_persons(state::SimulationState)::Nothing

Consistency checks (development mode only).
"""
function validate_all_persons(state::SimulationState)::Nothing
    for (id, person) in state.population.people
        # Check partner exists if partnership active
        if person.partner_id !== nothing
            partner = PopulationManager.get_person(state.population, person.partner_id)
            if partner === nothing
                @warn "Inconsistency: Person $id has partner $(person.partner_id), but partner doesn't exist!"
            end
        end
        
        # Check children <= desired
        if person.num_children > person.desired_children
            @warn "Inconsistency: Person $id has $(person.num_children) children but desired $(person.desired_children)"
        end
    end
end

end  # module SimulatorEngine

# Re-export key types and functions
export SimulatorConfig, PersonModule, EventEngine, 
       ProbabilityTables, PopulationManager, SimulatorEngine

end # module PopulationSimulator
