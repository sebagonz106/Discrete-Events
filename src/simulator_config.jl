"""
    SimulatorConfig

Global configuration and constants for population evolution simulator.
"""

module SimulatorConfig

export SimConfig, DEFAULT_CONFIG

struct SimConfig
    """Configuration holder for simulation parameters."""
    population_size::Int64           # Initial population in total
    simulation_years::Int64          # Total simulation duration (years)
    age_max::Int64                   # Maximum age in population
    fertility_age_min::Int64         # Minimum female fertility age
    fertility_age_max::Int64         # Maximum female fertility age
    pair_bond_age_min::Int64         # Minimum age for partnership
    
    function SimConfig(;
        population_size::Int64=500,
        simulation_years::Int64=100,
        age_max::Int64=125,
        fertility_age_min::Int64=12,
        fertility_age_max::Int64=70,
        pair_bond_age_min::Int64=12
    )
        new(
            population_size,
            simulation_years,
            age_max,
            fertility_age_min,
            fertility_age_max,
            pair_bond_age_min
        )
    end
end

# Default global configuration
const DEFAULT_CONFIG = SimConfig()

# Universal constants
const DAYS_PER_YEAR = 365
const DAYS_PER_SIMULATION = DEFAULT_CONFIG.simulation_years * DAYS_PER_YEAR
const GESTATION_PERIOD = 280  # 40 weeks
const INITIAL_MAX_AGE = 100

end # module
