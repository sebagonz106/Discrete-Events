# Step 2: System Architecture - Implementation Summary

## Overview

This directory contains the Julia infrastructure for the discrete-event population simulator, implementing Step 2 of the implementation plan.

## File Structure

```
src/
├── population_sim.jl            Main module (imports all sub-modules)
├── simulator_config.jl          Global configuration and constants
├── person.jl                    Person struct and enums
├── event_engine.jl              Event types and priority queue
├── probability_tables.jl        Probability distributions
├── population.jl                Population management and statistics
├── random_generators.jl         Random variable generation (uniform, exponential)
```

## Key Components

### 1. Configuration (`simulator_config.jl`)
- `SimConfig`: Configurable simulation parameters
- Default: 500 persons total, 100-year simulation, max age 125 years
- Fertility range: 12–70 years (female)
- Centralized constants (DAYS_PER_YEAR=365, GESTATION_PERIOD=280 days, INITIAL_MAX_AGE=100)

### 2. Person (`person.jl`)
- **Mutable struct** for state mutations throughout simulation
- Attributes:
  - Unique ID (auto-incremented globally)
  - Age in days (integer)
  - Sex (male/female enum)
  - Partnership state
  - Children count and desired count
  - Marital status (single/married/widowed/divorced)
  - Waiting period after separation (days)

### 3. Event Engine (`event_engine.jl`)
- **Concrete event types**:
  - `DeathEvent`: Person dies
  - `BirthEvent`: One or more babies born
  - `PregnancyAttemptEvent`: Woman may become pregnant
  - `MarriageEvent`: Partnership formed
  - `SeparationEvent`: Partnership dissolved
  - `EndWaitingPeriodEvent`: Waiting period after separation ends
  - `PartnerSearchEvent`: Active partner search
  - `YearEndEvent`: Annual aging and aggregation
- **EventQueue**: Min-heap priority queue (ordered by time_days)

### 4. Probability Tables (`probability_tables.jl`)
- All probability distributions extracted from source documents
- Age-bracketed lookups for:
  - Death probability (by age, sex)
  - Pregnancy probability (by age)
  - Partnership formation probabilities
  - Waiting period distributions
- Sampling functions:
  - Number of babies per birth
  - Desired children count
  - Initial population ages

### 5. Population Manager (`population.jl`)
- Dictionary-based population (ID → Person)
- Annual statistics tracking:
  - Population count
  - Births, deaths, marriages, separations
  - Median age, mean age, standard age error
  - Sex ratio (M/F)
- Functions:
  - Population initialization (random ages, random sex distribution)
  - Person lookup and removal
  - Statistics aggregation per year
  - CSV export (results.csv annually, population_age.csv decadally)

### 6. Random Generators (`random_generators.jl`)
- Inverse transform methods:
  - Uniform distribution (integer range)
  - Exponential distribution (λ parameter)
- Sex sampling (50/50 male/female)

## Validation

Run the test script to validate the architecture:

```bash
cd tests/
julia test_architecture.jl
```

This executes comprehensive tests covering:
1. Configuration loading
2. Person creation
3. Event type instantiation
4. Event queue ordering
5. Population initialization
6. Probability table lookups
7. Annual statistics aggregation

## Design Decisions

1. **Mutable Structs**: Mandatory for DES state mutations (age, partnership changes)
2. **Concrete Event Types**: Each event is its own struct type
3. **Dictionary-based Population**: O(1) lookup by ID, efficient for removals
4. **Priority Queue (BinaryMinHeap)**: O(log n) insertion/extraction for event ordering
5. **Integer Days**: All temporal calculations in complete days
6. **Auto-increment IDs**: Global counter ensures uniqueness without UUID overhead

## Next Steps

The event engine and population manager will be used in the DES motor implementation:
- Event processing logic
- Main simulation loop
- Statistics accumulation per year
