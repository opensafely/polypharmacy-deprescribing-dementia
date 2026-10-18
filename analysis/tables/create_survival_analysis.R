library(tidyverse)
library(survival)
library(gtsummary)
library(here)

source("analysis/utility.R")   # provides in_window_before_index()

dir.create(here("output", "tables"), recursive = TRUE, showWarnings = FALSE)

# ---- 1. Load and filter ------------------------------------------------------
df_master <- read_rds(here("output", "dataset_clean", "input_clean_cov.rds"))
years <- 2017:2024

# pivot to long format and filter to eligible patients
df_long <- df_master %>%
  pivot_longer(
    cols = matches(paste0("_(", paste(years, collapse = "|"), ")$")),
    names_to = c(".value", "year"),
    names_pattern = "(.+)_(\\d{4})$"
  ) %>%
  filter(inex_bin_all == TRUE)   # apply inclusion/exclusion criteria


# Repeat for each year
study_year <- 2017
df <- df_long %>% filter(year==study_year) %>%
  select(-matches("efi|frail"))   # add frailty back when ready

# ---- 2. Dates and outcome ----------------------------------------------------
index_date <- as.Date("2017-01-01")   # time zero
end_date   <- as.Date("2017-12-31")   # administrative end of follow-up

df <- df %>%
  mutate(
    across(c(cov_dat_chd, cov_dat_hosp, cov_dat_AE, exp_dat_med_rev), as.Date),
    
    # Outcome: first medication review in the study year
    review_date = if_else(
      exp_dat_med_rev >= index_date & exp_dat_med_rev <= end_date,
      exp_dat_med_rev, as.Date(NA)
    ),
    
    # death_date = as.Date(death_date),   # add when available
    # dereg_date = as.Date(dereg_date),   # add when available
    
    # Censor at end of year add this when we have the variables (pmin(end_date, death_date, dereg_date, na.rm = TRUE))
    censor_date = end_date,
    
    event     = !is.na(review_date) & review_date <= censor_date,
    stop_date = if_else(event, review_date, censor_date),
    
    # +1 so a review on 1 Jan has time = 1, not 0
    time = as.numeric(stop_date - index_date) + 1
  )

# ---- 3. Covariates -----------------------------------------------------------
df <- df %>%
  mutate(
    # Baseline flags (AMI, stroke, cancer, hypertension are already binary)
    cov_bin_chd_base = !is.na(cov_dat_chd) & cov_dat_chd < index_date,
    cov_bin_hosp_12m = in_window_before_index(cov_dat_hosp),
    cov_bin_AE_12m   = in_window_before_index(cov_dat_AE),
    
    # Add later: time since last review (before 1 Jan 2017), as categories
    # last_rev_date  <- as.Date(last_rev_date)
    # months_since_rev = as.numeric(index_date - last_rev_date) / 30.44,
    # time_since_rev   = cut(months_since_rev, c(0, 6, 12, 24, Inf), include.lowest = TRUE),
    # time_since_rev   = addNA(time_since_rev),   # "never reviewed" level
    
    # Add later: frailty
    
    # Factors 
    cov_cat_sex       = factor(cov_cat_sex),
    cov_cat_imd       = factor(cov_cat_imd),
    cov_cat_region    = factor(cov_cat_region),
    cov_cat_ethnicity = relevel(factor(cov_cat_ethnicity), ref = "White"),
    cov_cat_smoking   = relevel(factor(cov_cat_smoking), ref = "N"), 
  ) %>%
  # Drop raw dates and intermediate variables
  select(-cov_dat_chd, -cov_dat_hosp, -cov_dat_AE, -exp_dat_med_rev,
         -review_date, -censor_date, -stop_date)

# Prespecified predictors (used for all models).
# Dementia subtype and frailty / EFI left out for now.
predictors <- c(
  "cov_num_age", "cov_cat_sex", "cov_cat_ethnicity", "cov_cat_imd", "cov_cat_region",
  "cov_bin_chd_base", "cov_bin_ami", "cov_bin_stroke", "cov_bin_cancer",
  "cov_bin_hypertension", "cov_num_med_count", "cov_cat_smoking",
  "cov_num_cms", "cov_bin_carehome",
  "cov_bin_hosp_12m", "cov_bin_AE_12m"
  # "time_since_rev",   # add later
  # "frailty"       # add later
)

# ---- 4. Fit Cox models -------------------------------------------------------
# Single row per patient (one year), so no clustering needed yet.
# Add later - I want to add practice ID - add cluster(practice_id);

# Univariable: one model per predictor
tbl_uni <- df %>%
  tbl_uvregression(
    method       = coxph,
    y            = Surv(time, event),
    include      = all_of(predictors),
    exponentiate = TRUE
  )

# Multivariable: all predictors together
cox_fit <- df %>%
  coxph(reformulate(predictors, response = "Surv(time, event)"), data = .)

tbl_multi <- cox_fit %>%
  tbl_regression(exponentiate = TRUE)

# ---- 5. Results --------------------------------------------------------------
#later will add proportional hazards check here.

# Univariable results
tbl_uni$table_body %>%
  select(variable, label, estimate, conf.low, conf.high, p.value) %>%
  write_csv(here("output", "tables", "cox_univariable.csv"))

# Multivariable results
tbl_multi$table_body %>%
  select(variable, label, estimate, conf.low, conf.high, p.value) %>%
  write_csv(here("output", "tables", "cox_multivariable.csv"))
