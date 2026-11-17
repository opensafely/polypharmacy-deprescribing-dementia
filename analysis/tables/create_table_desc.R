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
# Both datasets have one row per patient per year, for patients eligible on 1 January of that year.
# Medication reviews come from the out dataset; region (on 1 January of each year) from the cov dataset
df <- read_rds(here("output", "dataset_clean", "input_clean_out.rds")) %>%
  select(patient_id, year, out_num_med_rev) %>%
  left_join(
    read_rds(here("output", "dataset_clean", "input_clean_cov.rds")) %>%
      select(patient_id, year, region = cov_cat_region),
    by = c("patient_id", "year")
  )

#------------------------------------------------
# Measures for each region and year:
# #1 number of eligible patients (N)
# #2 number of patients who had a medication review
# #3 total number of medication reviews
#------------------------------------------------
print("Calculating measures per region for each year")
measures <- df %>%
  group_by(region, year) %>%
  summarise(
    n_patients = n(),
    n_patients_med_rev = sum(out_num_med_rev > 0, na.rm = TRUE),
    n_med_rev = sum(out_num_med_rev, na.rm = TRUE),
    .groups = "drop"
  )

# One row per region, one column per year
measure_by_year <- function(measure, row_type) {
  measures %>%
    select(region, year, value = all_of(measure)) %>%
    pivot_wider(names_from = year, values_from = value, values_fill = 0, names_sort = TRUE) %>%
    mutate(row_type = row_type)
}

table_desc_region <- bind_rows(
  measure_by_year("n_patients", "Number of patients (N) by region"),
  measure_by_year("n_patients_med_rev", "Number of patients who had medication review by region"),
  measure_by_year("n_med_rev", "Number of medication reviews by region")
) %>%
  select(row_type, region, everything())

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