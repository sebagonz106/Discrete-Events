"""
    population_sim

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
using SimuladorPoblacion

config = SimuladorPoblacion.SimulatorConfig.DEFAULT_CONFIG
simulator = SimuladorPoblacion.SimulatorEngine.Simulator(config)
SimuladorPoblacion.SimulatorEngine.run_simulation!(simulator)
SimuladorPoblacion.SimulatorEngine.export_results(simulator, "./data/")
```
"""

module population_sim

# Include sub-modules in dependency order
include("simulator_config.jl")
include("random_generators.jl")
include("person.jl")
include("event_engine.jl")
include("probability_tables.jl")
include("population.jl")

# Re-export key types and functions
using .SimulatorConfig, .PersonModule, .EventEngine, 
      .ProbabilityTables, .PopulationManager

export SimulatorConfig, PersonModule, EventEngine, 
       ProbabilityTables, PopulationManager

end # module
