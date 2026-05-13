"""
    SimulatorConfig

Global configuration and constants for population evolution simulator.
"""

module SimulatorConfig

export SimConfig, DEFAULT_CONFIG

# Universal constants
const DAYS_PER_YEAR = 360
const DAYS_PER_MONTH = 30
const GESTATION_PERIOD = 280  # 40 weeks
const INITIAL_MAX_AGE = 100

struct SimConfig
    """Configuration holder for simulation parameters."""
    population_size::Int64           # Total initial population
    simulation_years::Int64          # Total simulation duration (years)
    total_days::Int64                # Computed: simulation_years * DAYS_PER_YEAR
    
    # Age parameters
    age_max::Int64                   # Maximum age in population
    fertility_age_min::Int64         # Minimum female fertility age
    fertility_age_max::Int64         # Maximum female fertility age
    pair_bond_age_min::Int64         # Minimum age for partnership
    
    # Debug/Development flags
    validate_consistency::Bool       # Validate population state after events
    verbose_logging::Bool            # Enable detailed year-by-year logs
    random_seed::Int64               # Random seed for reproducibility
    
    function SimConfig(;
        population_size::Int64=500,
        simulation_years::Int64=100,
        age_max::Int64=125,
        fertility_age_min::Int64=12,
        fertility_age_max::Int64=70,
        pair_bond_age_min::Int64=12,
        validate_consistency::Bool=false,
        verbose_logging::Bool=false,
        random_seed::Int64=42
    )
        new(
            population_size,
            simulation_years,
            simulation_years * DAYS_PER_YEAR,
            age_max,
            fertility_age_min,
            fertility_age_max,
            pair_bond_age_min,
            validate_consistency,
            verbose_logging,
            random_seed
        )
    end
end

# Default global configuration
const DEFAULT_CONFIG = SimConfig()


end # module
