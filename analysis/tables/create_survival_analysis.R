# Load libraries ---------------------------------------------------------------
library(readr)
library(tidyverse)
library(gtsummary)
library(here)
library(dplyr)
library(lubridate)
library(survival)
library(broom)

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

years <- 2017:2024
#pivot to long format
df_long <- df_master %>%
  pivot_longer(
    cols = matches(paste0("_(", paste(years, collapse = "|"), ")$")),
    names_to = c(".value", "year"),
    names_pattern = "(.+)_(\\d{4})$"
  ) %>%
  filter(
    year == 2017,
    inex_bin_all == TRUE
  )

index_date <- as.Date("2017-01-01")
end_date   <- as.Date("2017-12-31")

df_analysis <- df_long %>%
  # Drop EFI and frailty columns for now
  select(-matches("efi|frail")) %>%
  mutate(
    across(c(cov_dat_dem, cov_dat_chd, cov_dat_hosp, cov_dat_AE, exp_dat_med_rev),
           as.Date),
    
    # --- Baseline covariates from dates (status on/before index date) ---
    cov_bin_dem_base = !is.na(cov_dat_dem) & cov_dat_dem < index_date,
    cov_bin_chd_base = !is.na(cov_dat_chd) & cov_dat_chd < index_date,
    
    # Hospital / A&E contact in the 12 months before index
    cov_bin_hosp_12m = !is.na(cov_dat_hosp) &
      cov_dat_hosp < index_date & cov_dat_hosp >= index_date - years(1),
    cov_bin_AE_12m = !is.na(cov_dat_AE) &
      cov_dat_AE < index_date & cov_dat_AE >= index_date - years(1),
    
    # Review before the index date (prior review history)
    cov_bin_prior_med_rev = !is.na(exp_dat_med_rev) & exp_dat_med_rev < index_date,
    
    # --- Outcome: first medication review on/after index ---
    review_date = if_else(exp_dat_med_rev >= index_date, exp_dat_med_rev, as.Date(NA)),
    event       = !is.na(review_date) & review_date <= end_date,
    
    # --- Follow-up time (days) ---
    stop_date = if_else(event, review_date, end_date),
    time      = as.numeric(stop_date - index_date)
  ) %>%
  # Remove raw date columns so they can't leak into the model
  select(-cov_dat_dem, -cov_dat_chd, -cov_dat_hosp, -cov_dat_AE, -exp_dat_med_rev)

## Survival analysis
# Prepare model data -----------------------------------------------------------
df_model <- df_analysis %>%
  filter(time > 0) %>%   # coxph drops zero-time rows anyway; this makes it explicit
  mutate(
    cov_cat_sex       = factor(cov_cat_sex),
    cov_cat_ethnicity = relevel(factor(cov_cat_ethnicity), ref = "White"),
    cov_cat_imd       = factor(cov_cat_imd),   # check level order gives "1 (most deprived)" as ref
    cov_cat_region    = relevel(factor(cov_cat_region), ref = "East"),
    cov_cat_smoking   = factor(cov_cat_smoking)  # S/M/etc. - set ref to "N" (never) if present
  )

cox_formula <- Surv(time, event) ~
  cov_num_age + cov_cat_sex + cov_cat_ethnicity + cov_cat_imd + cov_cat_region +
  cov_bin_dem_base + cov_bin_chd_base + cov_bin_ami + cov_bin_stroke +
  cov_bin_cancer + cov_bin_hypertension + cov_bin_carehome +
  cov_cat_smoking + cov_num_med_count + cov_num_cms +
  cov_bin_hosp_12m + cov_bin_AE_12m + cov_bin_prior_med_rev


# Fit --------------------------------------------------------------------------

cox_fit <- coxph(cox_formula, data = df_model)
summary(cox_fit)

# Proportional hazards check ---------------------------------------------------
ph_test <- cox.zph(cox_fit)
print(ph_test)
# plot(ph_test)   # inspect Schoenfeld residual plots for any variables that fail

# Results table (hazard ratios) ------------------------------------------------
tbl_cox <- tbl_regression(cox_fit, exponentiate = TRUE)

tbl_cox %>%
  as_gt() %>%
  gt::gtsave(here("output", "tables", "cox_med_rev.html"))

# Or a plain CSV of HRs
tidy(cox_fit, exponentiate = TRUE, conf.int = TRUE) %>%
  write_csv(here("output", "tables", "cox_med_rev.csv"))

