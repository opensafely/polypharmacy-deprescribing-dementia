# Load libraries ---------------------------------------------------------------
library(readr)
library(tidyverse)
library(gtsummary)
library(here)
library(dplyr)
library(lubridate)
library(ggplot2)
# Source common functions ------------------------------------------------------
print("Source common functions")
source("analysis/utility.R")
#------------------------------------------------
# Create output directory
#------------------------------------------------
dir.create(here("output", "tables"), recursive = TRUE, showWarnings = FALSE)
dir.create(here("output", "figures"), recursive = TRUE, showWarnings = FALSE)
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
# Function: calculate frailty coverage (by type) and non-coverage,
# with a configurable lookback window
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
    valid_patients <- df %>% filter(.data[[inex_col]] == TRUE)
    n_valid <- n_distinct(valid_patients$patient_id)
    
    # Per-type counts (valid patients with that measure recorded within the window)
    n_mild     <- valid_patients %>% filter(valid_in_window(.data[[mild_col]]))   %>% summarise(n = n_distinct(patient_id)) %>% pull(n)
    n_moderate <- valid_patients %>% filter(valid_in_window(.data[[mod_col]]))    %>% summarise(n = n_distinct(patient_id)) %>% pull(n)
    n_severe   <- valid_patients %>% filter(valid_in_window(.data[[severe_col]])) %>% summarise(n = n_distinct(patient_id)) %>% pull(n)
    n_cfs      <- valid_patients %>% filter(valid_in_window(.data[[cfs_col]]))    %>% summarise(n = n_distinct(patient_id)) %>% pull(n)
    
    # Any-measure count (union across the 4 types)
    n_frailty <- valid_patients %>%
      filter(
        valid_in_window(.data[[mild_col]])   |
          valid_in_window(.data[[mod_col]])    |
          valid_in_window(.data[[severe_col]]) |
          valid_in_window(.data[[cfs_col]])
      ) %>%
      summarise(n = n_distinct(patient_id)) %>%
      pull(n)
    
    # Complement: valid patients with NO value in any of the 4 measures
    n_missing <- n_valid - n_frailty
    
    tibble(
      year         = yr,
      years_back   = years_back,
      n_valid      = n_valid,
      n_mild       = n_mild,
      pct_mild     = round(100 * n_mild / n_valid, 1),
      n_moderate   = n_moderate,
      pct_moderate = round(100 * n_moderate / n_valid, 1),
      n_severe     = n_severe,
      pct_severe   = round(100 * n_severe / n_valid, 1),
      n_cfs        = n_cfs,
      pct_cfs      = round(100 * n_cfs / n_valid, 1),
      n_frailty    = n_frailty,
      pct_frailty  = round(100 * n_frailty / n_valid, 1),
      n_missing    = n_missing,
      pct_missing  = round(100 * n_missing / n_valid, 1)
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

#------------------------------------------------
# Rounding function for redaction
#------------------------------------------------
roundmid_any <- function(x, to = 6) {
  # centers on (integer) midpoint of the rounding points
  x <- as.numeric(x)
  ceiling(x / to) * to - (floor(to / 2) * (x != 0))
}

#------------------------------------------------
# Create rounded version of the table
#------------------------------------------------
# Round every count column first (except n_missing, which is derived),
# then recalculate all percentages using the ROUNDED numerator and denominator
comparison_rounded <- comparison %>%
  mutate(
    n_valid    = roundmid_any(n_valid),
    n_mild     = roundmid_any(n_mild),
    n_moderate = roundmid_any(n_moderate),
    n_severe   = roundmid_any(n_severe),
    n_cfs      = roundmid_any(n_cfs),
    n_frailty  = roundmid_any(n_frailty)
  ) %>%
  mutate(
    # Derived, not independently rounded, so n_frailty + n_missing == n_valid
    n_missing = n_valid - n_frailty
  ) %>%
  mutate(
    pct_mild     = round(100 * n_mild     / n_valid, 1),
    pct_moderate = round(100 * n_moderate / n_valid, 1),
    pct_severe   = round(100 * n_severe   / n_valid, 1),
    pct_cfs      = round(100 * n_cfs      / n_valid, 1),
    pct_frailty  = round(100 * n_frailty  / n_valid, 1),
    pct_missing  = round(100 * n_missing  / n_valid, 1)
  ) %>%
  select(
    year, years_back, n_valid,
    n_mild, pct_mild,
    n_moderate, pct_moderate,
    n_severe, pct_severe,
    n_cfs, pct_cfs,
    n_frailty, pct_frailty,
    n_missing, pct_missing
  )

comparison_rounded

#------------------------------------------------
# Save rounded table
#------------------------------------------------
readr::write_csv(
  comparison_rounded,
  here("output", "tables", "frailty_coverage_by_lookback_rounded.csv")
)

#------------------------------------------------
# Reshape to long format for plotting
#------------------------------------------------
# Keep "any frailty" (pct_frailty) out of the plot by default since it's the
# union of the 4 types below, not a separate measure — but it's easy to add
# back in if you want it as an extra line (see note below).
plot_data <- comparison %>%
  select(year, years_back,
         pct_mild, pct_moderate, pct_severe, pct_cfs, pct_missing) %>%
  pivot_longer(
    cols = starts_with("pct_"),
    names_to = "measure",
    values_to = "pct",
    names_prefix = "pct_"
  ) %>%
  mutate(
    measure = recode(measure,
                     mild     = "Mild frailty",
                     moderate = "Moderate frailty",
                     severe   = "Severe frailty",
                     cfs      = "Clinical Frailty Score",
                     missing  = "No frailty measure recorded"),
    years_back_label = paste0(years_back, "-year lookback")
  )
#------------------------------------------------
# Plot: one panel per lookback window, one line per measure
#------------------------------------------------
p <- ggplot(plot_data, aes(x = year, y = pct, colour = measure)) +
  geom_line(linewidth = 1) +
  geom_point(size = 1.5) +
  facet_wrap(~ years_back_label, ncol = 2) +
  scale_x_continuous(breaks = years) +
  scale_y_continuous(limits = c(0, 100)) +
  labs(
    title = "Frailty measure coverage by year and lookback window",
    x = "Year",
    y = "% of valid patients",
    colour = "Measure"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    legend.position = "bottom"
  )

p

#------------------------------------------------
# Save table
#------------------------------------------------
readr::write_csv(
  comparison,
  here("output", "tables", "frailty_coverage_by_lookback.csv")
)

# Save it
ggsave(
  filename = here("output", "figures", "frailty_coverage_by_lookback.png"),
  plot = p,
  width = 10, height = 7, dpi = 300
)