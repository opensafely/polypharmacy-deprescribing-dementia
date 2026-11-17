"""Generate project.yaml for the OpenSAFELY pipeline.

project.yaml is written by this script and should not be edited by hand.
After changing the pipeline structure or the study dates in analysis/config.json,
re-run using python analysis/create_project_yaml.py

The cov, out and hist datasets are generated with one action per study year
(the years come from analysis/config.json) and then stacked by one cleaning action each.

Each action following the following structure:
    name     - action name
    run      - command to run
    needs    - list of actions it depends on (optional)
    outputs  - {privacy level: {output name: path}}; a key starting with "#"
               is written as a comment line (used to group outputs)
    comment  - comment lines written above the action (optional)
    disabled - if True, the action is written commented out (optional)
"""

import json
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

EHRQL = "ehrql:v1"
R = "r:v2"
DUMMY_TABLES = "--dummy-tables dummy_tables"

# Study years: every calendar year from start_date to end_date in analysis/config.json
with open(ROOT / "analysis" / "config.json") as f:
    config = json.load(f)
YEARS = list(range(date.fromisoformat(config["start_date"]).year,
                   date.fromisoformat(config["end_date"]).year + 1))

# If True, the cleaning actions for the yearly datasets also write describe-*.txt files
# (skimr summaries of the whole dataset). Useful for checking dummy data and early real-data
# runs; set to False to stop producing them as outputs.
DESCRIBE = True


# ---- Dataset actions ---------------------------------------------------------

def generate_dataset(name, needs=None, year=None):
    """Action that runs dataset_definition_<name>.py and writes input_<name>[_<year>].csv.gz.
    If year is given, it is passed to the dataset definition as --year."""
    suffix = f"_{year}" if year else ""
    output = f"output/dataset/input_{name}{suffix}.csv.gz"
    run = (f"{EHRQL} generate-dataset analysis/dataset_definition/dataset_definition_{name}.py "
           f"--output {output} {DUMMY_TABLES}")
    if year:
        run += f" -- --year {year}"
    action = {
        "name": f"generate_dataset_{name}{suffix}",
        "run": run,
        "outputs": {"highly_sensitive": {"dataset": output}},
    }
    if needs:
        action["needs"] = needs
    return action


def clean_dataset(name):
    """Action that runs dataset_clean.R on all years of a dataset and writes input_clean_<name>.rds"""
    outputs = {"highly_sensitive": {"dataset": f"output/dataset_clean/input_clean_{name}.rds"}}
    if DESCRIBE:
        outputs["moderately_sensitive"] = {
            "describe_preprocessed": f"output/describe/preprocessed-{name}.txt",
            "describe_ref": f"output/describe/ref-{name}.txt",
        }
    return {
        "name": f"clean_dataset_{name}",
        "run": f"{R} analysis/dataset_clean/dataset_clean.R {name} {str(DESCRIBE).upper()}",
        "needs": [f"generate_dataset_{name}_{year}" for year in YEARS],
        "outputs": outputs,
    }


def inex_actions():
    """Population for the whole study period (anyone who could be eligible at any point)."""
    return [
        generate_dataset("inex"),
        {
            "name": "clean_dataset_inex",
            "run": f"{R} analysis/dataset_clean/dataset_clean_inex.R",
            "needs": ["generate_dataset_inex"],
            "outputs": {
                "highly_sensitive": {"dataset": "output/dataset_clean/input_clean_inex.csv.gz"},
                "moderately_sensitive": {
                    "flow_inex": "output/dataset_clean/flow_inex.csv",
                    "flow_inex_midpoint6": "output/dataset_clean/flow_inex_midpoint6.csv",
                    "describe_inex_inex": "output/describe/inex-inex.txt",
                    "describe_preprocessed_inex": "output/describe/preprocessed-inex.txt",
                    "describe_qa_inex": "output/describe/qa-inex.txt",
                    "describe_ref_inex": "output/describe/ref-inex.txt",
                },
            },
        },
    ]


def dataset_actions(name):
    """Generate actions (one per study year) and a clean action for one of the cov / out / hist datasets."""
    return [
        generate_dataset(name, needs=["clean_dataset_inex"], year=year) for year in YEARS
    ] + [clean_dataset(name)]


# ---- Analysis actions --------------------------------------------------------

def table_action(name, script, needs, outputs, **kwargs):
    action = {
        "name": name,
        "run": f"{R} analysis/tables/{script}",
        "needs": needs,
        "outputs": {"moderately_sensitive": outputs},
    }
    action.update(kwargs)
    return action


def cum_inc_stop_any_outputs():
    outputs = {}
    for gap in [90, 120, 180]:
        outputs[f"# Any antihypertensive stopping ({gap}-day gap)"] = None
        outputs[f"stop_any_{gap}_table"] = f"output/tables/stop_any_{gap}_cum_inc.csv"
        outputs[f"stop_any_{gap}_table_midpoint6"] = f"output/tables/stop_any_{gap}_cum_inc_midpoint6.csv"
        outputs[f"stop_any_{gap}_plot"] = f"output/plots/stop_any_{gap}_cum_inc.png"
        outputs[f"stop_any_{gap}_plot_midpoint6"] = f"output/plots/stop_any_{gap}_cum_inc_midpoint6.png"
    return outputs


def analysis_actions():
    return [
        table_action(
            "create_table1_cov", "create_table1_cov.R",
            needs=["clean_dataset_cov", "clean_dataset_out"],
            outputs={
                "table_one_all_years": "output/tables/table1_cov_all_years.csv",
                "table_one_midpoint6_all_years": "output/tables/table1_cov_all_years_midpoint6.csv",
                "table_one_period_summary": "output/tables/table1_cov_period_summary.csv",
                "table_one_period_summary_midpoint6": "output/tables/table1_cov_period_summary_midpoint6.csv",
            },
        ),
        table_action(
            "create_table_desc", "create_table_desc.R",
            needs=["clean_dataset_out", "clean_dataset_cov"],
            outputs={
                "descptive_measures_table": "output/tables/table_desc_region.csv",
                "descptive_measures_table_midpoint6": "output/tables/table_desc_region_midpoint6.csv",
            },
        ),
        table_action(
            "create_cum_inc_med_rev", "create_table_cum_inc_med_rev.R",
            needs=["clean_dataset_out"],
            outputs={
                "medication_review_incidence_table": "output/tables/med_rev_cum_inc.csv",
                "medication_review_incidence_table_midpoint6": "output/tables/med_rev_cum_inc_midpoint6.csv",
                "medication_review_incidence": "output/plots/med_rev_cum_inc.png",
                "medication_review_incidence_midpoint6": "output/plots/med_rev_cum_inc_midpoint6.png",
            },
        ),
        table_action(
            "create_cum_inc_stop_any", "create_table_cum_inc_stop_any.R",
            needs=["clean_dataset_out"],
            outputs=cum_inc_stop_any_outputs(),
        ),
        table_action(
            "create_survival_analysis", "create_survival_analysis.R",
            needs=["clean_dataset_cov", "clean_dataset_out"],
            outputs={
                "cox_multivariable_table": "output/tables/cox_multivariable.csv",
                "cox_univariable_table": "output/tables/cox_univariable.csv",
                "cox_ph_test_table": "output/tables/cox_ph_test.csv",
            },
        ),
        table_action(
            "create_prescription_gaps_table", "create_table_prescription_gaps.R",
            needs=["clean_dataset_hist"],
            outputs={
                "prescription_gaps": "output/tables/prescription_gaps.csv",
                "prescription_gaps_midpoint6": "output/tables/prescription_gaps_midpoint6.csv",
            },
        ),
        table_action(
            "create_frailty_table", "create_frailty_table.R",
            needs=["clean_dataset_cov"],
            outputs={
                "frailty_investigation_table": "output/tables/frailty_coverage.csv",
                "frailty_investigation_table_midpoint6": "output/tables/frailty_coverage_midpoint6.csv",
                "frailty_coverage_plots": "output/figures/frailty_coverage.png",
            },
            comment=[
                "Frailty investigation: disabled until frailty variables are added back to the cov dataset",
                "(see add_frailty_variables() in add_variables.py)",
            ],
            disabled=True,
        ),
    ]


# ---- Writing the yaml --------------------------------------------------------

def format_action(action):
    lines = [f"{action['name']}:", f"  run: {action['run']}"]
    if action.get("needs"):
        lines.append(f"  needs: [{', '.join(action['needs'])}]")
    lines.append("  outputs:")
    for level, outputs in action["outputs"].items():
        lines.append(f"    {level}:")
        for key, path in outputs.items():
            if key.startswith("#"):
                lines.append(f"      {key}")
            else:
                lines.append(f"      {key}: {path}")

    prefix = "  # " if action.get("disabled") else "  "
    text = [f"  # {line}" for line in action.get("comment", [])]
    text += [prefix + line for line in lines]
    return "\n".join(text)


def main():
    actions = (
        inex_actions()
        + dataset_actions("cov")
        + dataset_actions("out")
        + dataset_actions("hist")
        + analysis_actions()
    )

    header = [
        "# This file is generated by analysis/create_project_yaml.py - do not edit it by hand.",
        "# To change the pipeline, edit that script and re-run: python analysis/create_project_yaml.py",
        "",
        "version: '5.0'",
        "",
        "actions:",
    ]
    body = "\n\n".join(format_action(a) for a in actions)

    out_path = ROOT / "project.yaml"
    out_path.write_text("\n".join(header) + "\n" + body + "\n", encoding="utf-8")
    print(f"Wrote {len(actions)} actions for {YEARS[0]}-{YEARS[-1]} to {out_path}")


if __name__ == "__main__":
    main()
