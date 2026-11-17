# Load libraries ---------------------------------------------------------------
library(tidyverse)
library(here)

# Source common functions ------------------------------------------------------
print("Source common functions")
source("analysis/utility.R")

#------------------------------------------------
# Load data
#------------------------------------------------
print("Load cleaned dataset")
# Define years -----------------------------------------------------------------
years <- 2017:2024

# Medication reviews come from the out dataset
df <- read_rds(here("output", "dataset_clean", "input_clean_out.rds"))

# Region comes from the cov dataset. For now this uses region at the start of the
# first study year for every year (as the old desc dataset did); this will change
# to each year's region when the data is moved to one row per patient-year.
# The column is still called desc_cat_region so the output table is unchanged.
df_region <- read_rds(here("output", "dataset_clean", "input_clean_cov.rds")) %>%
  select(patient_id, desc_cat_region = all_of(paste0("cov_cat_region_", years[1])))

df <- df %>%
  left_join(df_region, by = "patient_id")

# Create binary versions of out_num_ variables
df <- df %>%
  mutate(
    across(
      starts_with("out_num_"),
      ~ .x != 0,
      .names = "{sub('num', 'bin', .col)}"
    )
  )

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
# inex_bin_all TRUE AND out_bin_med_rev TRUE - split by region
#------------------------------------------------
print("Calculating patients who had medication review")

joint_counts_region <- df %>%
  group_by(desc_cat_region) %>%
  summarise(
    across(
      all_of(paste0("out_bin_med_rev_", years)),
      ~ sum(. == TRUE & get(sub("out_bin_med_rev_", "inex_bin_all_", cur_column())) == TRUE, na.rm = TRUE)
    ),
    .groups = "drop"
  ) %>%
  rename_with(~ gsub("out_bin_med_rev_", "", .), starts_with("out_bin_med_rev_")) %>%
  mutate(row_type = "Number of patients who had medication review by region")

table_desc_region <- bind_rows(table_desc_region, joint_counts_region)

#------------------------------------------------
# Measure #3 Total number of medication reviews
# Sum of out_num_med_rev where inex_bin_all TRUE - split by region
#------------------------------------------------
print("Calculating number of medication reviews")

medrev_counts_region <- df %>%
  group_by(desc_cat_region) %>%
  summarise(
    across(
      all_of(paste0("out_num_med_rev_", years)),
      ~ sum(.[get(sub("out_num_med_rev_", "inex_bin_all_", cur_column())) == TRUE], na.rm = TRUE)
    ),
    .groups = "drop"
  ) %>%
  rename_with(~ gsub("out_num_med_rev_", "", .), starts_with("out_num_med_rev_")) %>%
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