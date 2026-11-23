# This script takes patient level data for prescription gaps 

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

# One row per patient per year, for patients eligible on 1 January of that year
df <- readr::read_rds(
  here("output", "dataset_clean", "input_clean_hist.rds")
)

#------------------------------------------------
# Total number of gaps of each length, for each year and region
#------------------------------------------------
print("Summarising prescription gaps by year and region")
region_sums <- df %>%
  group_by(year, region = cov_cat_region) %>%
  summarise(
    across(
      starts_with("out_num_gap_"),
      ~ sum(.x, na.rm = TRUE)
    ),
    .groups = "drop"
  ) %>%
  select(region, year, everything())

#------------------------------------------------
# Save
#------------------------------------------------
print("Save to output/tables")

dir.create(
  here("output", "tables"),
  recursive = TRUE,
  showWarnings = FALSE
)

write_csv(
  region_sums,
  here("output", "tables", "prescription_gaps.csv")
)

#------------------------------------------------
# Create midpoint rounded version
#------------------------------------------------
print("Creating redacted / midpoint rounded prescription gaps")

region_sums_midpoint6 <- region_sums %>%
  mutate(
    across(
      starts_with("out_num_gap_"),
      ~ roundmid_any(.x),
      .names = "{.col}_midpoint6"
    )
  ) %>%
  select(
    year,
    region,
    ends_with("_midpoint6")
  )

#------------------------------------------------
# Save rounded table
#------------------------------------------------
print("Save redacted / midpoint rounded prescription gaps")

write_csv(
  region_sums_midpoint6,
  here("output", "tables", "prescription_gaps_midpoint6.csv")
)