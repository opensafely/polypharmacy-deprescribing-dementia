library(tidyverse)
library(survival)
library(gtsummary)
library(here)

source("analysis/utility.R")   # provides in_window_before_index() and tidy_cox_table()

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

# Prespecified predictors (used for all models).
# Frailty / EFI left out for now.
predictors <- c(
  "cov_num_age", "cov_cat_sex", "cov_cat_ethnicity", "cov_cat_imd", "cov_cat_region",
  # dementia subtype (not mutually exclusive)
  "cov_bin_dem_alz_base", "cov_bin_dem_vasc_base", "cov_bin_dem_other_base",   
  "cov_bin_chd_base", "cov_bin_ami", "cov_bin_stroke", "cov_bin_cancer",
  "cov_bin_hypertension", "cov_num_med_count", "cov_cat_smoking",
  "cov_num_cms", "cov_bin_carehome",
  "cov_bin_hosp_12m", "cov_bin_AE_12m",
  "cov_cat_time_since_rev"
  # "frailty"       # add later
)

# Results for each year are collected here and combined at the end
results_uni   <- list()
results_multi <- list()
results_ph    <- list()

# Run the analysis separately for each study year
for (study_year in years) {

  message("Running survival analysis for ", study_year)

  df <- df_long %>% filter(year==study_year) %>%
    select(-matches("efi|frail"))   # add frailty back when ready

  # ---- 2. Dates and outcome --------------------------------------------------
  index_date <- as.Date(paste0(study_year, "-01-01"))   # time zero
  end_date   <- as.Date(paste0(study_year, "-12-31"))   # administrative end of follow-up

  df <- df %>%
    mutate(
      # Outcome: first medication review in the study year
      review_date = if_else(
        (exp_dat_med_rev >= index_date) & (exp_dat_med_rev <= end_date),
        exp_dat_med_rev, as.Date(NA)
      ),

      # Censor at the earliest of death, deregistration or end of year
      censor_date = pmin(end_date, cens_dat_death, cens_dat_dereg, na.rm = TRUE),

      event     = !is.na(review_date) & review_date <= censor_date,
      stop_date = if_else(event, review_date, censor_date),

      # +1 so a review on 1 Jan has time = 1, not 0
      time = as.numeric(stop_date - index_date) + 1
    )

  # ---- 3. Covariates ---------------------------------------------------------
  df <- df %>%
    mutate(
      # Baseline flags (AMI, stroke, cancer, hypertension are already binary)
      cov_bin_chd_base = !is.na(cov_dat_chd) & cov_dat_chd < index_date,
      cov_bin_dem_alz_base   = !is.na(cov_dat_dem_alz) & cov_dat_dem_alz < index_date,
      cov_bin_dem_vasc_base  = !is.na(cov_dat_dem_vasc) & cov_dat_dem_vasc < index_date,
      cov_bin_dem_other_base = !is.na(cov_dat_dem_other) & cov_dat_dem_other < index_date,
      cov_bin_hosp_12m = in_window_before_index(cov_dat_hosp, index_date),
      cov_bin_AE_12m   = in_window_before_index(cov_dat_AE, index_date),

      # Time since last review (before 1 Jan of the study year), as categories
      months_since_rev       = as.numeric(index_date - cov_dat_last_med_rev) / 30.44,
      cov_cat_time_since_rev = cut(months_since_rev, c(0, 6, 12, 24, Inf), include.lowest = TRUE,
                                   labels = c("0-6 months", "6-12 months", "12-24 months", "24+ months")),
      cov_cat_time_since_rev = fct_na_value_to_level(cov_cat_time_since_rev, "Never reviewed"),

      # Add later: frailty

      # Factors
      cov_cat_sex       = factor(cov_cat_sex),
      cov_cat_imd       = factor(cov_cat_imd),
      cov_cat_region    = factor(cov_cat_region),
      cov_cat_ethnicity = relevel(factor(cov_cat_ethnicity), ref = "White"),
      cov_cat_smoking   = relevel(factor(cov_cat_smoking), ref = "N")
    ) %>%
    # Drop raw dates and intermediate variables
    select(-cov_dat_chd, -cov_dat_hosp, -cov_dat_AE, -exp_dat_med_rev,
           -cov_dat_dem_alz, -cov_dat_dem_vasc, -cov_dat_dem_other,
           -cov_dat_last_med_rev, -months_since_rev,
           -cens_dat_death, -cens_dat_dereg,
           -review_date, -censor_date, -stop_date)

  # ---- 4. Fit Cox models -----------------------------------------------------
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

  # Proportional hazards check (Schoenfeld residuals) for the multivariable model
  ph_test <- cox.zph(cox_fit)

  results_uni[[as.character(study_year)]]   <- tidy_cox_table(tbl_uni, study_year)
  results_multi[[as.character(study_year)]] <- tidy_cox_table(tbl_multi, study_year)
  results_ph[[as.character(study_year)]]    <- as.data.frame(ph_test$table) %>%
    rownames_to_column("term") %>%   # one row per predictor, plus GLOBAL
    mutate(year = study_year) %>%
    select(year, term, chisq, df, p)
}

# ---- 5. Results --------------------------------------------------------------
# All years stacked, with a year column

# Univariable results
bind_rows(results_uni) %>%
  write_csv(here("output", "tables", "cox_univariable.csv"))

# Multivariable results
bind_rows(results_multi) %>%
  write_csv(here("output", "tables", "cox_multivariable.csv"))

# Proportional hazards test results (p < 0.05 suggests the assumption may not hold)
bind_rows(results_ph) %>%
  write_csv(here("output", "tables", "cox_ph_test.csv"))
