#!/usr/bin/env python3
"""
Plotter for Discrete Events Simulation results.

Reads aggregated results from the aggregated-results/ folder and generates
plots for population, sex ratio, and age metrics.

Usage:
    python plot.py --type simple --plot population
    python plot.py --type param --plot sratio
    python plot.py --plot age  (type defaults to simple)
    python plot py --type param (plot defaults to population)
"""

import argparse
import os
import json
import sys
from pathlib import Path
from typing import Tuple, Optional
import textwrap
import re
from datetime import datetime

import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import seaborn as sns

# Set seaborn style for better aesthetics
sns.set_style("darkgrid")
plt.rcParams['figure.figsize'] = (12, 6)


def find_latest_experiment(experiment_type: str) -> Tuple[str, str]:
    """
    Find the latest experiment results by TIMESTAMP in aggregated-results/.

    Identification is done purely by filename using the pattern:
        {experiment_type}_{TIMESTAMP}_*.csv
    where TIMESTAMP is expected in the format YYYYMMDD_HHMMSS.

    Args:
        experiment_type: 'simple' or 'param'

    Returns:
        Tuple of (results_csv_path, description_json_path)

    Raises:
        FileNotFoundError: If no matching experiment found
    """
    aggregated_dir = Path("aggregated-results")

    if not aggregated_dir.exists():
        raise FileNotFoundError(f"Directory '{aggregated_dir}' not found.")

    # Match files that start with the experiment_type prefix and end with _results.csv
    pattern = re.compile(rf'^{re.escape(experiment_type)}_(\d{{8}}_\d{{6}}).*_results\.csv$')

    candidates = []
    for p in aggregated_dir.iterdir():
        if not p.is_file():
            continue
        m = pattern.match(p.name)
        if m:
            ts_str = m.group(1)
            try:
                ts = datetime.strptime(ts_str, "%Y%m%d_%H%M%S")
            except ValueError:
                # fallback to file mtime if timestamp is malformed
                ts = datetime.fromtimestamp(p.stat().st_mtime)
            candidates.append((p, ts_str, ts))

    if not candidates:
        raise FileNotFoundError(f"No {experiment_type} experiment results found in {aggregated_dir}")

    # Choose the candidate with the newest timestamp
    candidates.sort(key=lambda x: x[2], reverse=True)
    latest_path, latest_ts_str, _ = candidates[0]

    # Compose expected description file path for the same timestamp (may or may not exist)
    # Description files include the experiment prefix, e.g. 'param_TIMESTAMP_description.json'
    description_path = aggregated_dir / f"{experiment_type}_{latest_ts_str}_description.json"

    return str(latest_path), str(description_path)


def load_results(results_csv: str) -> pd.DataFrame:
    """Load results CSV into DataFrame."""
    return pd.read_csv(results_csv)


def load_description(description_json: str) -> dict:
    """Load experiment description JSON."""
    desc_path = Path(description_json)
    if not desc_path.exists():
        return {}
    with open(description_json) as f:
        return json.load(f)


def _format_description_text(description: dict, width: int = 60) -> str:
    """Format the description dict into a short multi-line string for the verbose plot."""
    lines = []
    name = description.get("experiment_name") or description.get("experiment")
    if name:
        lines.append(str(name))
    desc = description.get("experiment_description") or description.get("description")
    if desc:
        # Wrap long description
        wrapped = textwrap.fill(str(desc), width=width)
        lines.append(wrapped)
    params = description.get("parameters")
    if params and isinstance(params, dict):
        # show a compact params line
        params_items = [f"\n{k}={v}" for k, v in params.items() if k in ("num_simulations", "simulation_years")]
        if params_items:
            lines.append(
                textwrap.fill("; ".join(params_items), width=width)
            )

    # Fallback: if nothing found, show full JSON truncated
    if not lines and description:
        lines.append(textwrap.fill(json.dumps(description), width=width))

    return "\n\n".join(lines)


def plot_population(
    results_df: pd.DataFrame,
    description: dict,
    experiment_type: str,
    save_path: Optional[str] = None,
    verbose_save_path: Optional[str] = None
) -> None:
    """
    Plot population (total, males, females) with error bars.

    Args:
        results_df: DataFrame with results
        description: Experiment description dict
        experiment_type: 'simple' or 'param'
        save_path: Optional path to save figure
    """
    fig, ax = plt.subplots(figsize=(12, 6))

    if experiment_type == "simple":
        x_col = "year"
        pop_col = "population_mean"
        pop_se_col = "population_se"
        males_col = "males_mean"
        females_col = "females_mean"
        x_label = "Year"
    else:  # param
        # Get the x column name (the parameter name)
        axes = description.get("axes", {})
        x_col = axes.get("x", "param_value")
        pop_col = "population_final_mean"
        pop_se_col = "population_final_se"
        males_col = "males_final_mean"
        females_col = "females_final_mean"
        x_label = axes.get("x_label", x_col)

    x_data = results_df[x_col]

    # Total population
    ax.errorbar(
        x_data, results_df[pop_col],
        yerr=results_df[pop_se_col],
        fmt="-o", linewidth=2, markersize=6,
        label="Total Population", color="#1f77b4", capsize=5
    )

    # Males
    ax.errorbar(
        x_data, results_df[males_col],
        yerr=None,  # No SEs for males
        fmt="-s", linewidth=2, markersize=6,
        label="Males", color="#ff7f0e", capsize=5
    )

    # Females
    ax.errorbar(
        x_data, results_df[females_col],
        yerr=None,  # No SEs for females
        fmt="-^", linewidth=2, markersize=6,
        label="Females", color="#2ca02c", capsize=5
    )

    ax.set_xlabel(x_label, fontsize=12, fontweight="bold")
    ax.set_ylabel("Population", fontsize=12, fontweight="bold")
    ax.set_title("Population Over Time" if experiment_type == "simple" else "Population vs Parameter",
                 fontsize=14, fontweight="bold")
    ax.legend(fontsize=10, loc="best")
    ax.grid(True, alpha=0.3)

    plt.tight_layout()

    # Show and optionally save
    if save_path:
        plt.savefig(save_path, dpi=300, bbox_inches="tight")
        print(f"✓ Population plot saved to: {save_path}")

    # Save a verbose version with the description box if requested
    if verbose_save_path and description:
        txt = None
        try:
            text = _format_description_text(description)
            txt = ax.text(
                0.01, 0.02, text,
                transform=ax.transAxes,
                ha='left', va='bottom', fontsize=8,
                bbox=dict(boxstyle='round', facecolor='white', alpha=0.9)
            )
            plt.savefig(verbose_save_path, dpi=300, bbox_inches='tight')
            print(f"✓ Verbose population plot saved to: {verbose_save_path}")
        finally:
            if txt is not None:
                txt.remove()

    plt.show()


def plot_sex_ratio(
    results_df: pd.DataFrame,
    description: dict,
    experiment_type: str,
    save_path: Optional[str] = None,
    verbose_save_path: Optional[str] = None
) -> None:
    """
    Plot sex ratio with error bars.

    Args:
        results_df: DataFrame with results
        description: Experiment description dict
        experiment_type: 'simple' or 'param'
        save_path: Optional path to save figure
    """
    fig, ax = plt.subplots(figsize=(12, 6))

    if experiment_type == "simple":
        x_col = "year"
        sr_col = "sex_ratio_mean"
        sr_se_col = "sex_ratio_se"
        x_label = "Year"
    else:  # param
        axes = description.get("axes", {})
        x_col = axes.get("x", "param_value")
        sr_col = "sex_ratio_final_mean"
        sr_se_col = "sex_ratio_final_se"
        x_label = axes.get("x_label", x_col)

    x_data = results_df[x_col]

    ax.errorbar(
        x_data, results_df[sr_col],
        yerr=results_df[sr_se_col],
        fmt="-o", linewidth=2, markersize=8,
        label="Sex Ratio (M/F)", color="#d62728", capsize=5
    )

    ax.set_xlabel(x_label, fontsize=12, fontweight="bold")
    ax.set_ylabel("Sex Ratio (Males/Females)", fontsize=12, fontweight="bold")
    ax.set_title("Sex Ratio Over Time" if experiment_type == "simple" else "Sex Ratio vs Parameter",
                 fontsize=14, fontweight="bold")
    ax.legend(fontsize=10, loc="best")
    ax.grid(True, alpha=0.3)

    plt.tight_layout()

    if save_path:
        plt.savefig(save_path, dpi=300, bbox_inches="tight")
        print(f"✓ Sex ratio plot saved to: {save_path}")

    if verbose_save_path and description:
        txt = None
        try:
            text = _format_description_text(description)
            txt = ax.text(
                0.98, 0.02, text,
                transform=ax.transAxes,
                ha='right', va='bottom', fontsize=8,
                bbox=dict(boxstyle='round', facecolor='white', alpha=0.9)
            )
            plt.savefig(verbose_save_path, dpi=300, bbox_inches='tight')
            print(f"✓ Verbose sex-ratio plot saved to: {verbose_save_path}")
        finally:
            if txt is not None:
                txt.remove()

    plt.show()


def plot_age(
    results_df: pd.DataFrame,
    description: dict,
    experiment_type: str,
    save_path: Optional[str] = None,
    verbose_save_path: Optional[str] = None
) -> None:
    """
    Plot average age with error bars.

    Args:
        results_df: DataFrame with results
        description: Experiment description dict
        experiment_type: 'simple' or 'param'
        save_path: Optional path to save figure
    """
    fig, ax = plt.subplots(figsize=(12, 6))

    if experiment_type == "simple":
        x_col = "year"
        age_col = "avg_age_mean"
        age_se_col = "avg_age_se"
        x_label = "Year"
    else:  # param
        axes = description.get("axes", {})
        x_col = axes.get("x", "param_value")
        age_col = "avg_age_final_mean"
        age_se_col = "avg_age_final_se"
        x_label = axes.get("x_label", x_col)

    x_data = results_df[x_col]

    ax.errorbar(
        x_data, results_df[age_col],
        yerr=results_df[age_se_col],
        fmt="-o", linewidth=2, markersize=8,
        label="Average Age", color="#9467bd", capsize=5
    )

    ax.set_xlabel(x_label, fontsize=12, fontweight="bold")
    ax.set_ylabel("Average Age (years)", fontsize=12, fontweight="bold")
    ax.set_title("Average Age Over Time" if experiment_type == "simple" else "Average Age vs Parameter",
                 fontsize=14, fontweight="bold")
    ax.legend(fontsize=10, loc="best")
    ax.grid(True, alpha=0.3)

    plt.tight_layout()

    if save_path:
        plt.savefig(save_path, dpi=300, bbox_inches="tight")
        print(f"✓ Age plot saved to: {save_path}")

    if verbose_save_path and description:
        txt = None
        try:
            text = _format_description_text(description)
            txt = ax.text(
                0.98, 0.02, text,
                transform=ax.transAxes,
                ha='right', va='bottom', fontsize=8,
                bbox=dict(boxstyle='round', facecolor='white', alpha=0.9)
            )
            plt.savefig(verbose_save_path, dpi=300, bbox_inches='tight')
            print(f"✓ Verbose age plot saved to: {verbose_save_path}")
        finally:
            if txt is not None:
                txt.remove()

    plt.show()


def main() -> None:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Plot Discrete Events Simulation results"
    )
    parser.add_argument(
        "--type",
        choices=["simple", "param"],
        default="simple",
        help="Experiment type: 'simple' or 'param' (default: simple)"
    )
    parser.add_argument(
        "--plot",
        choices=["population", "sratio", "age"],
        default="population",
        help="Metric to plot (default: population)"
    )

    args = parser.parse_args()

    try:
        print(f"Searching for {args.type} experiment...")
        results_csv, description_json = find_latest_experiment(args.type)
        print(f"✓ Found: {results_csv}")

        results_df = load_results(results_csv)
        description = load_description(description_json)

        # Create plots directory if saving
        plots_dir = Path("plots")
        plots_dir.mkdir(exist_ok=True)

        # Generate filename for saving (existing behavior)
        header = Path(results_csv).stem.split("_results")[0]
        save_filename = f"plots/{header}_{args.plot}.png"

        # Also build the requested verbose filename using args.type and the timestamp
        # extract timestamp from header (expected format: {type}_YYYYMMDD_HHMMSS)
        ts_match = re.search(r"\d{8}_\d{6}", header)
        if ts_match:
            ts = ts_match.group(0)
        else:
            # fallback to current time
            ts = datetime.now().strftime("%Y%m%d_%H%M%S")

        verbose_save_filename = f"plots/{args.type}_{ts}_{args.plot}_verbose.png"

        # Route to appropriate plot function (pass verbose path)
        if args.plot == "population":
            plot_population(results_df, description, args.type, save_filename, verbose_save_filename)
        elif args.plot == "sratio":
            plot_sex_ratio(results_df, description, args.type, save_filename, verbose_save_filename)
        elif args.plot == "age":
            plot_age(results_df, description, args.type, save_filename, verbose_save_filename)

        print(f"\n✓ Plot for '{args.plot}' completed successfully!")

    except FileNotFoundError as e:
        print(f"✗ Error: {e}", file=sys.stderr)
        sys.exit(1)
    except KeyError as e:
        print(f"✗ Column not found in results CSV: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"✗ Unexpected error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
