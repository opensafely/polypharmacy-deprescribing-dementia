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

# assuming your dataset is called df
# 1. Summarise counts per region
region_sums <- df %>%
  group_by(cov_cat_region) %>%
  summarise(across(starts_with("out_cnt_gap_"), function(x) sum(x, na.rm = TRUE))) %>%
  ungroup() %>%

  bind_rows(
    df %>%
      summarise(
        across(starts_with("out_cnt_gap_"), function(x) sum(x, na.rm = TRUE))
      ) %>%
      mutate(cov_cat_region = "Overall"))

#------------------------------------------------
# Save
#------------------------------------------------
print("Save to output/tables")
dir.create(here("output", "tables"), recursive = TRUE, showWarnings = FALSE)
write_csv(region_sums, here("output", "tables", "prescription_gaps.csv"))
