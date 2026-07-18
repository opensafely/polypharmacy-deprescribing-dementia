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
# Create output directory
#------------------------------------------------
dir.create(here("output", "tables"), recursive = TRUE, showWarnings = FALSE)

#------------------------------------------------
# Load data
#------------------------------------------------
print("Load cleaned dataset")
df_master <- readr::read_rds(here("output", "dataset_clean", "input_clean_cov.rds"))


#------------------------------------------------
# Create binary indicators for "cov_dat_" variables
#------------------------------------------------
print("Create derived variables")
df_master <- df_master %>%
  mutate(across(starts_with("cov_dat_"), ~ !is.na(.x), .names = "{sub('dat', 'bin', .col)}"))

# Create binary exposed variable
df_master <- df_master %>%
  mutate(across(starts_with("exp_dat_med_rev"), ~ !is.na(.x), .names = "{sub('dat', 'bin', .col)}"))


years <- 2017:2024
#pivot to long format
df_long <- df_master %>%
  pivot_longer(
    cols = matches(paste0("_(", paste(years, collapse = "|"), ")$")),
    names_to = c(".value", "year"),
    names_pattern = "(.+)_(\\d{4})$"
  )

# create table1 across years
# this runs the create_table1 function for each year, and appends the rows each time
table1_by_year <- map_dfr(
  years,
  function(yr) {
    
    print(paste0("Creating Table 1 for year: ", yr))
    
    df_year <- df_long %>%
      filter(
        year == yr,
        inex_bin_all == TRUE
      )
    
    create_table1(df_year) %>%
      mutate(
        year = yr,
        .before = everything()
      )
    
  }
)

#create pooled table1
#filter to eligible patients 
df_pooled <- df_long %>%
  filter(inex_bin_all == TRUE)

#pick first eligible year
df_pooled <- df_pooled %>%
  arrange(patient_id, year) %>%
  group_by(patient_id) %>%
  slice_head(n = 1) %>%
  ungroup()

print("Creating table 1 for all years")
table1_pooled <- create_table1(df_pooled)

print("Creating redacted versions")

table1_pooled_midpoint6 <- create_midpoint6_table1(
  table1_pooled
)

table1_by_year_midpoint6 <- table1_by_year %>%
  group_by(year) %>%
  group_modify(~ create_midpoint6_table1(.x)) %>%
  ungroup()

#Write tables
print("Saving Table 1 outputs")
write_csv(table1_by_year, here("output", "tables", "table1_cov_all_years.csv"))
write_csv(table1_pooled, here("output", "tables", "table1_cov_period_summary.csv"))

write_csv(table1_by_year_midpoint6, here("output", "tables", "table1_cov_all_years_midpoint6.csv"))
write_csv(table1_pooled_midpoint6, here("output", "tables", "table1_cov_period_summary_midpoint6.csv"))


