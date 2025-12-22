# Load libraries ---------------------------------------------------------------
library(readr)
library(tidyverse)
library(gtsummary)
library(here)
library(dplyr)

# Source common functions ------------------------------------------------------
print("Source common functions")
source("analysis/utility.R")

#------------------------------------------------
# Load data
#------------------------------------------------
print("Load cleaned dataset")
df <- readr::read_rds(here("output", "dataset_clean", "input_clean.rds"))

# 1. Summarise counts per region
region_sums <- df %>%
  group_by(cov_cat_region) %>%
  summarise(across(starts_with("out_num_gap_"), function(x) sum(x, na.rm = TRUE))) %>%
  ungroup() %>%
  mutate(cov_cat_region = as.character(cov_cat_region)) %>%

  bind_rows(
  df %>%
    group_by(cov_bin_carehome) %>%
    summarise(across(starts_with("out_num_gap_"), function(x) sum(x, na.rm = TRUE))) %>%
    ungroup() %>%
      rename(cov_cat_region = cov_bin_carehome) %>%
      mutate(cov_cat_region = as.character(cov_cat_region))
  ) %>%

  bind_rows(
    df %>%
      summarise(
        across(starts_with("out_num_gap_"), function(x) sum(x, na.rm = TRUE))
      ) %>%
      mutate(cov_cat_region = "Overall"))

#------------------------------------------------
# Save
#------------------------------------------------
print("Save to output/tables")
dir.create(here("output", "tables"), recursive = TRUE, showWarnings = FALSE)
write_csv(region_sums, here("output", "tables", "histograms_table.csv"))