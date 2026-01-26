# Load libraries ---------------------------------------------------------------

library(tidyverse)
library(yaml)
library(here)
library(glue)
library(readr)
library(dplyr)

# Create generic action function -----------------------------------------------

action <- function(
  name,
  run,
  dummy_data_file = NULL,
  arguments = NULL,
  needs = NULL,
  highly_sensitive = NULL,
  moderately_sensitive = NULL
) {
  # Only append arguments to run if not NULL
  run_full <- if (!is.null(arguments)) {
    paste0(run, "\n  ", paste(arguments, collapse = "\n  "))
  } else {
    run
  }
  outputs <- list(
    moderately_sensitive = moderately_sensitive,
    highly_sensitive = highly_sensitive
  )
  outputs[sapply(outputs, is.null)] <- NULL

  actions <- list(
    run = run_full,
    dummy_data_file = dummy_data_file,
    needs = needs,
    outputs = outputs
  )
  actions[sapply(actions, is.null)] <- NULL

  action_list <- list(name = actions)
  names(action_list) <- name

  action_list
}

# Create generic comment function ----------------------------------------------

comment <- function(...) {
  list_comments <- list(...)
  comments <- map(list_comments, ~ paste0("## ", ., " ##"))
  comments
}


# Create function to convert comment "actions" in a yaml string into proper comments

convert_comment_actions <- function(yaml.txt) {
  yaml.txt %>%
    str_replace_all("\\\n(\\s*)\\'\\'\\:(\\s*)\\'", "\n\\1") %>%
    #str_replace_all("\\\n(\\s*)\\'", "\n\\1") %>%
    str_replace_all("([^\\'])\\\n(\\s*)\\#\\#", "\\1\n\n\\2\\#\\#") %>%
    str_replace_all("\\#\\#\\'\\\n", "\n")
}

# Add cohort-specific measure actions ------------------------------------------
generate_cohort <- function(cohort) {
  splice(
    comment(glue("Generate cohort - {cohort}")),
    action(
      name = glue("generate_cohort_{cohort}"),
      run = glue(
        "ehrql:v1 generate-dataset analysis/dataset_definition/measures_cohorts.py --output output/dataset_definition/input_{cohort}.csv.gz"
      ),
      arguments = c(glue("--cohort {cohort}")),
      highly_sensitive = list(
        dataset = glue("output/dataset_definition/input_{cohort}.csv.gz")
      )
    )
  )
}

# Generate cleaned input
generate_input_clean <- function(cohort) {
  splice(
    comment(glue("Generate cleaned input dataset - {cohort}")),
    action(
      name = glue("generate_input_{cohort}_clean"),
      run = glue("r:latest analysis/dataset_clean/dataset_clean.R {cohort}"),
      needs = list(
        glue("generate_cohort_{cohort}"),
        glue("generate_merged_{cohort}")
      ),
      highly_sensitive = list(
        cohort_clean = glue("output/dataset_clean/input_{cohort}_clean.rds")
      )
    )
  )
}

# Generate Table 1
generate_table1 <- function(cohort) {
  splice(
    comment(glue("Generate Table 1 summary statistics - {cohort}")),
    action(
      name = glue("generate_table1_{cohort}"),
      run = glue("r:latest analysis/table1/table1.R {cohort}"),
      needs = list(
        glue("generate_input_{cohort}_clean")
      ),
      moderately_sensitive = list(
        table1_midpoint6 = glue(
          "output/table1/table1-cohort_{cohort}-midpoint6.csv"
        )
      )
    )
  )
}

write_project_yaml <- function(path = "project.yaml",tag) {
  yaml_lines <- c(
    "version: '4.0'",
    "",
    "actions:",
    sprintf("  generate_dataset_prematch_%s:", tag),
    "    run: ehrql:v1 generate-dataset analysis/dataset_definition/dataset_definition_prematch.py --output output/dataset/input_prematch.csv.gz --dummy-tables dummy_tables -- --cohort covid",
    "    outputs:",
    "      highly_sensitive:",
    "        dataset: output/dataset/input_prematch.csv.gz",
    "",
    "  clean_dataset_prematch:",
    "    run: r:v2 analysis/dataset_clean/dataset_clean_prematch.R",
    "    needs: [generate_dataset_prematch]",
    "    outputs:",
    "      highly_sensitive:",
    "        dataset: output/dataset_clean/input_clean_prematch.csv",
    "      moderately_sensitive:",
    "        flow_prematch: output/dataset_clean/flow_prematch.csv",
    "        describe_inex_prematch: output/describe/inex-prematch.txt",
    "        describe_preprocessed_prematch: output/describe/preprocessed-prematch.txt",
    "        describe_qa_prematch: output/describe/qa-prematch.txt",
    "        describe_ref_prematch: output/describe/ref-prematch.txt",
    "",
    "  generate_dataset_hist:",
    "    run: ehrql:v1 generate-dataset analysis/dataset_definition/dataset_definition_hist.py --output output/dataset/input_hist.csv.gz --dummy-tables dummy_tables",
    "    needs: [clean_dataset_prematch]",
    "    outputs:",
    "      highly_sensitive:",
    "        dataset: output/dataset/input_hist.csv.gz",
    "",
    "  generate_dataset_match:",
    "    run: ehrql:v1 generate-dataset analysis/dataset_definition/dataset_definition_match.py --output output/dataset/input_match.csv.gz --dummy-tables dummy_tables",
    "    needs: [clean_dataset_prematch]",
    "    outputs:",
    "      highly_sensitive:",
    "        dataset: output/dataset/input_match.csv.gz",
    "",
    "  match:",
    "    run: r:v2 analysis/dataset_clean/match.R",
    "    needs: [generate_dataset_match]",
    "    outputs:",
    "      highly_sensitive:",
    "        dataset: output/dataset_clean/input_matched.csv",
    "",
    "  generate_dataset_matched:",
    "    run: ehrql:v1 generate-dataset analysis/dataset_definition/dataset_definition_matched.py --output output/dataset/input_matched.csv.gz --dummy-tables dummy_tables",
    "    needs: [match]",
    "    outputs:",
    "      highly_sensitive:",
    "        dataset: output/dataset/input_matched.csv.gz",
    "",
    "  clean_dataset_matched:",
    "    run: r:v2 analysis/dataset_clean/dataset_clean_matched.R",
    "    needs: [generate_dataset_matched]",
    "    outputs:",
    "      highly_sensitive:",
    "        dataset: output/dataset_clean/input_clean_matched.csv",
    "      moderately_sensitive:",
    "        flow: output/dataset_clean/flow_matched.csv",
    "        describe_inex: output/describe/inex-matched.txt",
    "        describe_preprocessed: output/describe/preprocessed-matched.txt",
    "        describe_qa: output/describe/qa-matched.txt",
    "        describe_ref: output/describe/ref-matched.txt",
    "",
    "  generate_dataset_matched_full:",
    "    run: ehrql:v1 generate-dataset analysis/dataset_definition/dataset_definition_matched_full.py --output output/dataset/input_matched_full.csv.gz --dummy-tables dummy_tables",
    "    needs: [clean_dataset_matched]",
    "    outputs:",
    "      highly_sensitive:",
    "        dataset: output/dataset/input_matched_full.csv.gz",
    "",
    "  clean_dataset_hist:",
    "    run: r:v2 analysis/dataset_clean/dataset_clean_hist.R",
    "    needs: [generate_dataset_hist]",
    "    outputs:",
    "      highly_sensitive:",
    "        dataset: output/dataset_clean/input_clean_hist.rds",
    "      moderately_sensitive:",
    "        describe_preprocessed: output/describe/preprocessed-hist.txt",
    "        describe_ref: output/describe/ref-hist.txt",
    "",
    "  create_table1_hist:",
    "   run: r:v2 analysis/tables/create_table1_hist.R",
    "   needs: [clean_dataset_hist]",
    "   outputs:",
    "     moderately_sensitive:",
    "       table_one: output/tables/table1_hist.csv",
    "       table_one_midpoint6: output/tables/table1_hist_midpoint6.csv",
    "",
    "  create_prescription_gaps_table:",
    "   run: r:v2 analysis/tables/create_table_prescription_gaps.R",
    "   needs: [clean_dataset_hist]",
    "   outputs:",
    "     moderately_sensitive:",
    "       prescription_gaps: output/tables/prescription_gaps.csv",
    "       prescription_gaps_midpoint6: output/tables/prescription_gaps_midpoint6.csv",
    "",
    "  # generate_project_dag:",
    "  #   run: python:v2 python analysis/project_dag.py --yaml-path project.yaml --output-path project.dag.md",
    "  #   outputs:",
    "  #     moderately_sensitive:",
    "  #       counts: project.dag.md"
  )
  
  writeLines(yaml_lines, con = path)
  invisible(path)
}

