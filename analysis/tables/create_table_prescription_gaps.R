#This script takes patient level data for prescription gaps 

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

df <- readr::read_rds(
  here("output", "dataset_clean", "input_clean_hist.rds")
)


#------------------------------------------------
# Years to process
#------------------------------------------------
years <- 2017:2024

#------------------------------------------------
# Create summaries for each year
#------------------------------------------------
region_sums <- map_dfr(years, function(year) {
  
  print(paste("Processing year:", year))
  
  # Dynamic column names
  region_var <- paste0("desc_cat_region", year)
  inex_var   <- paste0("inex_bin_all_", year)
  
  outcome_cols <- names(df) %>%
    str_subset(paste0("^out_num_gap_.*", year, "$"))
  
  
  # Keep only relevant columns for this year
  df_year <- df %>%
    select(
      patient_id,
      all_of(region_var),
      all_of(inex_var),
      matches(paste0(year, "$"))
    ) %>%
    filter(.data[[inex_var]] == TRUE)
  
  # Region summaries
  region_summary <- df_year %>%
    group_by(.data[[region_var]]) %>%
    summarise(
      across(
        starts_with("out_num_gap_"),
        ~ sum(.x, na.rm = TRUE)
      ),
      .groups = "drop"
    ) %>%
    rename(region = all_of(region_var))
  
  # Overall summary
  overall_summary <- df_year %>%
    summarise(
      across(
        starts_with("out_num_gap_"),
        ~ sum(.x, na.rm = TRUE)
      )
    ) %>%
    mutate(region = "Overall")
  
  df_final <- bind_rows(region_summary, overall_summary) %>%
    mutate(year = year) %>%
    rename_with(
      .cols = all_of(outcome_cols),
      .fn = ~ str_remove(.x, paste0("_", year, "$"))
    ) %>%
    select(region, year, everything())
  
})

overall_all_years <- region_sums %>%
  filter(region == "Overall") %>%
  summarise(
    across(
      where(is.numeric),
      ~ sum(.x, na.rm = TRUE)
    )
  ) %>%
  mutate(region = "Overall (all years)")

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