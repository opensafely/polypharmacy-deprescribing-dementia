# ==============================================================================
# Time to first medication review, 2017 cohort
# Cox proportional hazards model with baseline covariates
# ==============================================================================

# 1. Setup ---------------------------------------------------------------------
library(tidyverse)   # includes dplyr, readr, tidyr
library(lubridate)
library(survival)
library(gtsummary)
library(broom)
library(here)

source("analysis/utility.R")

dir.create(here("output", "tables"), recursive = TRUE, showWarnings = FALSE)

# Study parameters
study_year <- 2017
index_date <- as.Date("2017-01-01")   # start of follow-up
end_date   <- as.Date("2017-12-31")   # administrative end of follow-up (placeholder:
# add death / deregistration dates when available)

# 2. Load data -----------------------------------------------------------------
df_master <- read_rds(here("output", "dataset_clean", "input_clean_cov.rds"))

# 3. Reshape to one row per patient for the study year -------------------------
# Year-specific columns are named <variable>_<year>; keep only the study year.
df_long <- df_master %>%
  pivot_longer(
    cols          = matches(paste0("_", study_year, "$")),
    names_to      = c(".value", "year"),
    names_pattern = "(.+)_(\\d{4})$"
  ) %>%
  filter(inex_bin_all == TRUE)   # apply inclusion/exclusion criteria

# 4. Derive baseline covariates, outcome and follow-up time --------------------
# TRUE if a date falls in the `months` before the index date
in_window_before_index <- function(date, months = 12) {
  !is.na(date) & date < index_date & date >= index_date %m-% months(months)
}

df_analysis <- df_long %>%
  select(-matches("efi|frail")) %>%   # frailty measures not ready yet
  mutate(
    across(c(cov_dat_dem, cov_dat_chd, cov_dat_hosp, cov_dat_AE, exp_dat_med_rev),
           as.Date),
    
    # Baseline status from dates (occurred before index)
    cov_bin_dem_base = !is.na(cov_dat_dem) & cov_dat_dem < index_date,
    cov_bin_chd_base = !is.na(cov_dat_chd) & cov_dat_chd < index_date,
    
    # Hospital / A&E contact in the 12 months before index
    cov_bin_hosp_12m = in_window_before_index(cov_dat_hosp),
    cov_bin_AE_12m   = in_window_before_index(cov_dat_AE),
    
    # Prior review history
    cov_bin_prior_med_rev = !is.na(exp_dat_med_rev) & exp_dat_med_rev < index_date,
    
    # Outcome: first review on/after index, within follow-up
    review_date = if_else(exp_dat_med_rev >= index_date, exp_dat_med_rev, as.Date(NA)),
    event       = !is.na(review_date) & review_date <= end_date,
    
    # Follow-up time in days
    stop_date = if_else(event, review_date, end_date),
    time      = as.numeric(stop_date - index_date)
  ) %>%
  # Drop raw dates so they can't leak into the model
  select(-cov_dat_dem, -cov_dat_chd, -cov_dat_hosp, -cov_dat_AE,
         -exp_dat_med_rev, -review_date, -stop_date)

# 5. Prepare model data --------------------------------------------------------
# Check levels() for each factor to confirm the reference categories make sense.
df_model <- df_analysis %>%
  filter(time > 0) %>%   # zero-time rows are dropped by coxph anyway
  mutate(
    cov_cat_sex       = factor(cov_cat_sex),
    cov_cat_ethnicity = relevel(factor(cov_cat_ethnicity), ref = "White"),
    cov_cat_imd       = factor(cov_cat_imd),                       # check ref is "1 (most deprived)"
    cov_cat_region    = relevel(factor(cov_cat_region), ref = "East"),
    cov_cat_smoking   = factor(cov_cat_smoking)                    # consider setting ref to never-smoker
  )

# 6. Fit Cox model -------------------------------------------------------------
# Dementia subtype flags (alz/vasc/other) are omitted in favour of the single
# baseline dementia flag to avoid overlap.
cox_formula <- Surv(time, event) ~
  cov_num_age + cov_cat_sex + cov_cat_ethnicity + cov_cat_imd + cov_cat_region +
  cov_bin_dem_base + cov_bin_chd_base + cov_bin_ami + cov_bin_stroke +
  cov_bin_cancer + cov_bin_hypertension + cov_bin_carehome +
  cov_cat_smoking + cov_num_med_count + cov_num_cms +
  cov_bin_hosp_12m + cov_bin_AE_12m + cov_bin_prior_med_rev

cox_fit <- coxph(cox_formula, data = df_model)
summary(cox_fit)

# 7. Check proportional hazards ------------------------------------------------
ph_test <- cox.zph(cox_fit)
print(ph_test)
# plot(ph_test)   # inspect Schoenfeld residuals for any variables that fail

# 8. Save results --------------------------------------------------------------
# Formatted HR table (HTML)
tbl_regression(cox_fit, exponentiate = TRUE) %>%
  as_gt() %>%
  gt::gtsave(here("output", "tables", "cox_med_rev.html"))

# Plain CSV of hazard ratios
tidy(cox_fit, exponentiate = TRUE, conf.int = TRUE) %>%
  write_csv(here("output", "tables", "cox_med_rev.csv"))