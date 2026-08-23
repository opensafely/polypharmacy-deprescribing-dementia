# Load libraries ---------------------------------------------------------------
library(readr)
library(tidyverse)
library(gtsummary)
library(here)
library(dplyr)
library(lubridate)

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

df_frail <- df_master %>%
  select(
    patient_id,
    starts_with("inex_bin_all"),
    starts_with("cov_dat_mildfrail"),
    starts_with("cov_dat_moderatefrail"),
    starts_with("cov_dat_severefrail"),
    starts_with("cov_dat_clinfrailscr"),
    starts_with("cov_num_latest_efi")
  )

#------------------------------------------------
# Function: calculate frailty coverage with a configurable lookback window
#------------------------------------------------
# years_back = 1  -> only the single year immediately before counts as valid
# years_back = 10 -> any date within the 10 years before counts as valid
calc_frailty_counts <- function(df, years, years_back = 1) {
  
  lapply(years, function(yr) {
    
    inex_col   <- paste0("inex_bin_all_", yr)
    mild_col   <- paste0("cov_dat_mildfrail_", yr)
    mod_col    <- paste0("cov_dat_moderatefrail_", yr)
    severe_col <- paste0("cov_dat_severefrail_", yr)
    cfs_col    <- paste0("cov_dat_clinfrailscr_", yr)

    window_start <- yr - years_back
    window_end   <- yr - 1
    
    # Helper: TRUE only if the date falls within [window_start, window_end]
    valid_in_window <- function(date_col) {
      d <- as.Date(date_col)
      !is.na(d) & lubridate::year(d) >= window_start & lubridate::year(d) <= window_end
    }
    
    # Denominator: all "valid" patients for the year (inex_bin_all == TRUE)
    n_valid <- df %>%
      filter(.data[[inex_col]] == TRUE) %>%
      summarise(n = n_distinct(patient_id)) %>%
      pull(n)
    
    # Numerator: valid patients who also have a frailty date within the lookback window
    n_frailty <- df %>%
      filter(.data[[inex_col]] == TRUE) %>%
      filter(
        valid_in_window(.data[[mild_col]])   |
          valid_in_window(.data[[mod_col]])    |
          valid_in_window(.data[[severe_col]]) |
          valid_in_window(.data[[cfs_col]])
      ) %>%
      summarise(n = n_distinct(patient_id)) %>%
      pull(n)
    
    tibble(
      year          = yr,
      years_back    = years_back,
      n_valid       = n_valid,
      n_frailty     = n_frailty,
      pct_frailty   = round(100 * n_frailty / n_valid, 1)
    )
  }) %>%
    bind_rows()
}

#------------------------------------------------
# Run it
#------------------------------------------------
years <- 2017:2024

comparison <- bind_rows(
  calc_frailty_counts(df_frail, years, years_back = 1),
  calc_frailty_counts(df_frail, years, years_back = 3),
  calc_frailty_counts(df_frail, years, years_back = 5),
  calc_frailty_counts(df_frail, years, years_back = 100)
  
)
comparison

