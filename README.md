# Discrete Events Population Simulator

A Julia-based discrete events simulator for modeling population dynamics. Supports individual simulations and statistical experiments (evolution tracking and parameter sensitivity analysis).

## Overview

This project simulates a population with births, deaths, and demographic events over time. It provides:
- **Individual simulations**: single-run population dynamics
- **Statistical experiments**: multi-run aggregation with error estimates
- **Parameter exploration**: sensitivity analysis on demographic parameters
- **Visualization**: plot results with `plot.py`

## Repository Structure

```
Discrete-Events/
├── Project.toml              # Julia project dependencies
├── main.jl                   # CLI entry point for experiments
├── plot.py                   # Python plotter for results
├── src/
│   ├── simulator_config.jl   # SimConfig type and configuration
│   ├── population.jl         # Population management and exports
│   ├── population_sim.jl     # Main simulator engine
│   └── experiments/
│       ├── base.jl           # Experiment base types and utilities
│       ├── simple_evolution.jl    # Multi-run evolution tracking
│       └── parameter_comparison.jl # Parameter sensitivity analysis
├── individual-results/       # Per-simulation outputs (CSV, age distribution, config)
├── aggregated-results/       # Experiment aggregated outputs with error bars
├── plots/                    # Generated plot images
└── tests/                    # Unit tests for core modules
```

## File Descriptions

### Core Simulation
- **`simulator_config.jl`**: Defines `SimConfig` (immutable configuration: population size, demographics, fertility rates, random seed, simulation years).
- **`population.jl`**: `PopulationManager` module handling population state, event scheduling, births/deaths, and CSV exports (results, age distribution).
- **`population_sim.jl`**: `PopulationSimulator` module wrinking `SimulatorEngine` and `run_simulation()` — the main entry point for executing a single simulation.

### Experiments & Aggregation
- **`src/experiments/base.jl`**: Common types (`ExperimentConfig`, `ExperimentMetadata`), helpers for JSON export, timestamp generation, and statistics calculation (mean, std dev, standard error).
- **`src/experiments/simple_evolution.jl`**: Runs N simulations and aggregates yearly statistics (population, sex ratio, age) with error bars.
- **`src/experiments/parameter_comparison.jl`**: Varies one demographic parameter across multiple values, runs N simulations per value, aggregates final metrics.

### CLI & Plotting
- **`main.jl`**: Command-line entry point; supports:
  - `julia main.jl 1 [seed]` — Simple evolution experiment
  - `julia main.jl 2 [seed]` — Parameter comparison experiment
- **`plot.py`**: Python plotter supporting:
  - `--type simple|param` (which experiment to plot)
  - `--plot population|sratio|age` (which metric)
  - Saves normal and verbose (with metadata) PNG images.

## Getting Started

### Prerequisites
- **Julia** (≥ 1.9)
- **Python** (≥ 3.8) with `pandas`, `matplotlib`, `seaborn`

### Installation

```bash
cd Discrete-Events
julia --project=. -e 'import Pkg; Pkg.instantiate(); Pkg.precompile()'
pip install pandas matplotlib seaborn
```

### Running Simulations

#### Individual Simulation
```julia
julia -e '
using Pkg; Pkg.activate(".")
include("src/population_sim.jl")
using .PopulationSimulator

config = SimulatorConfig.SimConfig(
    population_size=500,
    male_population=250,
    age_max=100,
    fertility_age_min=15,
    fertility_age_max=50,
    simulation_years=10,
    random_seed=42
)

PopulationSimulator.SimulatorEngine.run_simulation(config; export_results=true)
'
```
Outputs CSVs to `individual-results/` (timestamped).

#### Experiments

**Simple Evolution** (10 runs, track yearly stats):
```bash
cd Discrete-Events
julia --project=. main.jl 1 42
```

**Parameter Comparison** (vary population_size across [100, 300, 500, 800, 1200]):
```bash
cd Discrete-Events
julia --project=. main.jl 2 777
```

Results saved to `aggregated-results/` with config and description JSONs.

### Plotting Results

```bash
cd Discrete-Events

# Simple evolution: population plot
python plot.py --type simple --plot population

# Parameter comparison: sex ratio plot
python plot.py --type param --plot sratio

# Age metrics (defaults to simple)
python plot.py --plot age
```

Generates PNG images in `plots/` (normal and verbose with experiment metadata).

## Configuration

Edit experiment parameters in `main.jl` or directly in `SimConfig`:
- `population_size`: initial population
- `male_population`: initial males
- `age_max`: maximum lifespan
- `fertility_age_min`, `fertility_age_max`: reproductive age range
- `simulation_years`: duration
- `random_seed`: reproducibility

## Output Files

### Individual Simulation
- `YYYYMMDD_HHMMSS_results.csv` — yearly population metrics
- `YYYYMMDD_HHMMSS_population_age.csv` — age distribution
- `YYYYMMDD_HHMMSS_config.json` — simulation parameters

### Experiment Aggregation
- `{type}_YYYYMMDD_HHMMSS_results.csv` — aggregated metrics with standard error
- `{type}_YYYYMMDD_HHMMSS_config.json` — experiment configuration
- `{type}_YYYYMMDD_HHMMSS_description.json` — metadata for plotting

## License

See `LICENSE` file.
