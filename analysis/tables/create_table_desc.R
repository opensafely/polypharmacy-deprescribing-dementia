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
df <- read_rds(here("output", "dataset_clean", "input_clean_desc.rds"))

# Create binary versions of desc_num_ variables
df <- df %>%
  mutate(
    across(
      starts_with("desc_num_"),
      ~ .x != 0,
      .names = "{sub('num', 'bin', .col)}"
    )
  )

# Define years -----------------------------------------------------------------
years <- 2017:2024

#------------------------------------------------
# Measure #1 Count of eligible patients (N) - split by region
#------------------------------------------------
print("Calculating number of eligible patients per region for each year")
table_desc_region <- df %>%
  group_by(desc_cat_region) %>%
  summarise(
    across(starts_with("inex_bin_all_"), ~ sum(. == TRUE, na.rm = TRUE)),
    .groups = "drop"
  ) %>%
  rename_with(~ as.character(years), starts_with("inex_bin_all_")) %>%
  mutate(row_type = "Number of patients (N) by region")

#------------------------------------------------
# Measure #2 Count patients who have medication review
# inex_bin_all TRUE AND desc_bin_med_rev TRUE - split by region
#------------------------------------------------
print("Calculating patients who had medication review")

joint_counts_region <- df %>%
  group_by(desc_cat_region) %>%
  summarise(
    across(
      all_of(paste0("desc_bin_med_rev_", years)),
      ~ sum(. == TRUE & get(sub("desc_bin_med_rev_", "inex_bin_all_", cur_column())) == TRUE, na.rm = TRUE)
    ),
    .groups = "drop"
  ) %>%
  rename_with(~ gsub("desc_bin_med_rev_", "", .), starts_with("desc_bin_med_rev_")) %>%
  mutate(row_type = "Number of patients who had medication review by region")

table_desc_region <- bind_rows(table_desc_region, joint_counts_region)

#------------------------------------------------
# Measure #3 Total number of medication reviews
# Sum of desc_num_med_rev where inex_bin_all TRUE - split by region
#------------------------------------------------
print("Calculating number of medication reviews")

medrev_counts_region <- df %>%
  group_by(desc_cat_region) %>%
  summarise(
    across(
      all_of(paste0("desc_num_med_rev_", years)),
      ~ sum(.[get(sub("desc_num_med_rev_", "inex_bin_all_", cur_column())) == TRUE], na.rm = TRUE)
    ),
    .groups = "drop"
  ) %>%
  rename_with(~ gsub("desc_num_med_rev_", "", .), starts_with("desc_num_med_rev_")) %>%
  mutate(row_type = "Number of medication reviews by region")

table_desc_region <- bind_rows(table_desc_region, medrev_counts_region)

#------------------------------------------------
# Reorder columns so row_type is first
#------------------------------------------------
print("Reordering columns")

table_desc_region <- table_desc_region %>%
  select(row_type, desc_cat_region, everything())

#------------------------------------------------
# Save
#------------------------------------------------
print("Save table_desc_region to output/tables")
dir.create(here("output", "tables"), recursive = TRUE, showWarnings = FALSE)

write_csv(table_desc_region, here("output", "tables", "table_desc_region.csv"))

#------------------------------------------------
# Create midpoint6 rounded version
#------------------------------------------------
print("Creating redacted / midpoint rounded version of table_desc_region")

table_desc_region_midpoint6 <- table_desc_region %>%
  rename_with(
    ~ paste0(.x, "_midpoint6"),
    matches("^\\d{4}$")   # selects year columns
  ) %>%
  mutate(
    across(
      matches("^\\d{4}_midpoint6$"),
      ~ roundmid_any(.x)
    )
  )

#------------------------------------------------
# Save
#------------------------------------------------
print("Save table_desc_region_midpoint6 to output/tables")
dir.create(here("output", "tables"), recursive = TRUE, showWarnings = FALSE)

write_csv(table_desc_region_midpoint6, here("output", "tables", "table_desc_region_midpoint6.csv"))