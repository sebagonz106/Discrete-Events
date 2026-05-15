module ExperimentRunner

using Dates
using CSV
using DataFrames
# Optional: JSON for description metadata; fallback to plain text if not present
try
    @eval using JSON
    const HAS_JSON = true
catch
    const HAS_JSON = false
end

export ExperimentConfig, ParamSpec, run_experiment, main

"""
ExperimentConfig
Holds experiment-level settings.
- `name`: short experiment name
- `n_replicates`: replicates per parameter set for statistical validity
- `output_dir`: where to write aggregated results (relative to project root)
- `seed`: base random seed (optional)
- `parallel`: :none / :threads / :distributed (optional, extensible)
"""
struct ExperimentConfig
    name::String
    n_replicates::Int
    output_dir::String
    seed::Union{Int,Nothing}
    parallel::Symbol
end

"""
ParamSpec
Defines a parameter to sweep:
- `key` : Symbol matching a field in SimConfig
- `values` : Vector of allowed values
"""
struct ParamSpec
    key::Symbol
    values::Vector
end

"""
RunResult
Container for a single simulation run result (one replicate).
Fields are generic: include `paramset` (Dict), `replicate_id`, `metrics` (Dict), `timeline` (Vector/DF) etc.
"""
struct RunResult
    paramset::Dict{Symbol,Any}
    replicate::Int
    metrics::Dict{String,Real}
    timeline::DataFrame   # optional per-year timeseries if available
end

# Utility: timestamp string for filenames
timestamp() = Dates.format(now(), "yyyy-mm-dd_HHMMSS")

# Build Cartesian product of parameter specs -> returns Vector{Dict{Symbol,Any}}
function build_param_grid(specs::Vector{ParamSpec})
    lists = [s.values for s in specs]
    keys = [s.key for s in specs]
    grid = []
    for combo in Iterators.product(lists...)
        param = Dict{Symbol,Any}()
        for (k,v) in zip(keys, combo)
            param[k] = v
        end
        push!(grid, param)
    end
    return grid
end

# A wrapper that adapts a paramset (Dict) into your SimConfig and runs one simulation.
# Must be adapted to your project: replace `make_simconfig(param)` and `run_simulation(simconfig)`
function run_single(paramset::Dict{Symbol,Any}, replicate::Int; base_seed=nothing)
    # Build simulation config: must map param keys to your SimConfig fields
    simconfig = make_simconfig(paramset)   # <<-- implement mapping to your SimConfig
    if base_seed !== nothing
        simconfig = set_seed!(simconfig, base_seed + replicate) # optional helper
    end

    # Run simulation (replace with your engine call) and collect outputs
    sim_output = run_simulation(simconfig) # <<-- expected to return: metrics Dict and optional timeline DataFrame

    metrics = sim_output.metrics      # Dict{String,Real}
    timeline = get(sim_output, :timeline, DataFrame())  # if provided
    return RunResult(paramset, replicate, metrics, timeline)
end

# Aggregate a vector of RunResult -> aggregated DataFrame (means, std, n, percentiles)
function aggregate_results(results::Vector{RunResult}; group_keys=keys(first(results).paramset))
    # flatten metrics per run to DataFrame
    rows = DataFrame()
    for r in results
        row = Dict{Symbol,Any}()
        for (k,v) in r.paramset
            row[k] = v
        end
        row[:replicate] = r.replicate
        for (mname, mval) in r.metrics
            row[Symbol(mname)] = mval
        end
        push!(rows, row)
    end

    # produce summary (groupby paramset columns)
    gcols = collect(group_keys)
    grouped = groupby(rows, gcols)
    agg_rows = DataFrame()
    for g in grouped
        s = Dict{Symbol,Any}()
        for k in gcols
            s[k] = first(g)[k]
        end
        n = nrow(g)
        s[:n] = n
        for cname in names(g)
            if cname ∈ vcat(gcols, [:replicate]) continue end
            vals = skipmissing(g[!, cname])
            s[Symbol(string(cname)*"_mean")] = mean(vals)
            s[Symbol(string(cname)*"_std")]  = length(vals) > 1 ? std(vals) : 0.0
            s[Symbol(string(cname)*"_p50")]  = quantile(collect(vals), 0.5)
            s[Symbol(string(cname)*"_p10")]  = quantile(collect(vals), 0.10)
            s[Symbol(string(cname)*"_p90")]  = quantile(collect(vals), 0.90)
        end
        push!(agg_rows, s)
    end
    return (raw=rows, aggregate=agg_rows)
end

# Save functions
function ensure_output_dir(dir::String)
    mkpath(dir)
end

function save_results_csv(df::DataFrame, outdir::String, ts::String)
    fname = joinpath(outdir, string(ts, "_results.csv"))
    CSV.write(fname, df)
    return fname
end

function save_plot_csv(df::DataFrame, outdir::String, ts::String)
    fname = joinpath(outdir, string(ts, "_plot.csv"))
    CSV.write(fname, df)
    return fname
end

# Save description (JSON if possible, else plain text)
function save_description(desc::Dict{String,Any}, outdir::String, ts::String)
    fname = joinpath(outdir, string(ts, "_description.json"))
    if HAS_JSON
        open(fname, "w") do io
            JSON.print(io, desc)
        end
    else
        open(fname, "w") do io
            for (k,v) in desc
                println(io, "$k: $v")
            end
        end
    end
    return fname
end

# Main experiment loop:
# - build grid
# - for each paramset run n_replicates and collect RunResult
# - aggregate and export CSVs and description
function run_experiment(cfg::ExperimentConfig, specs::Vector{ParamSpec}; make_simconfig, run_simulation, set_seed! = nothing)
    ts = timestamp()
    outdir = joinpath(cfg.output_dir)
    ensure_output_dir(outdir)

    grid = build_param_grid(specs)
    all_results = RunResult[]
    for (i,paramset) in enumerate(grid)
        for rep in 1:cfg.n_replicates
            rr = run_single(paramset, rep; base_seed=(cfg.seed === nothing ? nothing : cfg.seed + i),)
            push!(all_results, rr)
        end
    end

    # Aggregate
    agg = aggregate_results(all_results)

    # Convert and save
    raw_df = agg.raw
    agg_df = agg.aggregate

    results_path = save_results_csv(raw_df, outdir, ts)
    plot_path    = save_plot_csv(agg_df, outdir, ts)

    description = Dict(
        "experiment" => cfg.name,
        "timestamp" => ts,
        "n_replicates" => cfg.n_replicates,
        "param_specs" => [ (string(s.key)=>s.values) for s in specs ],
        "results_file" => results_path,
        "plot_file" => plot_path
    )
    desc_path = save_description(description, outdir, ts)

    return (results_path, plot_path, desc_path)
end

# Simple CLI/main
function main()
    # Example default config
    cfg = ExperimentConfig("example", 30, joinpath(@__DIR__, "..", "aggregated-results"), 42, :none)

    # Example parameter specs (customize ranges)
    specs = [
        ParamSpec(:population_size, [100, 500, 1000]),
        ParamSpec(:male_population, [-1, 0, 50]),
        ParamSpec(:age_max, [80, 100, 120]),
        ParamSpec(:fertility_age_min, [12]),
        ParamSpec(:fertility_age_max, [45, 55])
    ]

    println("Running experiment: ", cfg.name)
    # The following call requires the user to provide concrete `make_simconfig` and `run_simulation`.
    # Pass them as anonymous functions or adapt `run_experiment` to call your module directly.
    # Example:
    # run_experiment(cfg, specs; make_simconfig=my_make_simconfig, run_simulation=MySimulator.run_simulation)

    println("Done. Implement a call to `run_experiment` with your simulator functions.")
end

end # module