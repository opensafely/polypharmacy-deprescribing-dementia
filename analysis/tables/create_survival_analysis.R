library(tidyverse)
library(survival)
library(gtsummary)
library(here)

source("analysis/utility.R")   # provides in_window_before_index() and tidy_cox_table()

dir.create(here("output", "tables"), recursive = TRUE, showWarnings = FALSE)

# ---- 1. Load and filter ------------------------------------------------------
df_master <- read_rds(here("output", "dataset_clean", "input_clean_cov.rds"))
years <- 2017:2024
gap_sizes <- c(90, 120, 180)   # gap sizes used to define stopping a medication

# Stopping dates come from the desc dataset (one column per drug class, gap size and year)
df_stop <- read_rds(here("output", "dataset_clean", "input_clean_desc.rds")) %>%
  select(patient_id, starts_with("desc_dat_stop_"))

# "Stop any": earliest stop across all drug classes, for each gap size and year
for (gap in gap_sizes) {
  for (yr in years) {
    cols_this_year <- str_subset(names(df_stop), paste0("^desc_dat_stop_.+_", gap, "_", yr, "$"))
    new_col <- paste0("out_dat_stop_any_", gap, "_", yr)
    df_stop[[new_col]] <- if (length(cols_this_year) > 0) {
      do.call(pmin, c(df_stop[cols_this_year], na.rm = TRUE))
    } else {
      as.Date(NA)
    }
  }
}

df_master <- df_master %>%
  left_join(select(df_stop, patient_id, starts_with("out_dat_stop_any_")), by = "patient_id")

# pivot to long format and filter to eligible patients
df_long <- df_master %>%
  pivot_longer(
    cols = matches(paste0("_(", paste(years, collapse = "|"), ")$")),
    names_to = c(".value", "year"),
    names_pattern = "(.+)_(\\d{4})$"
  ) %>%
  filter(inex_bin_all == TRUE)   # apply inclusion/exclusion criteria

# Outcomes to model: name used in the output = date column in df_long
outcomes <- c(
  med_rev = "exp_dat_med_rev",   # first medication review
  setNames(paste0("out_dat_stop_any_", gap_sizes), paste0("stop_any_", gap_sizes))   # first stop of any antihypertensive
)

# Prespecified predictors (used for all models).
# Frailty / EFI left out for now.
predictors <- c(
  "cov_num_age", "cov_cat_sex", "cov_cat_ethnicity", "cov_cat_imd", "cov_cat_region",
  # dementia subtype (not mutually exclusive)
  "cov_bin_dem_alz_base", "cov_bin_dem_vasc_base", "cov_bin_dem_other_base",
  "cov_bin_chd_base", "cov_bin_ami", "cov_bin_stroke", "cov_bin_cancer",
  "cov_bin_hypertension", "cov_num_med_count", "cov_cat_smoking",
  # "cov_num_cms",   # add back when CMS memory issue is resolved
  "cov_bin_carehome",
  "cov_bin_hosp_12m", "cov_bin_AE_12m",
  "cov_cat_time_since_rev"
  # "frailty"       # add later
)

# Results for each outcome and year are collected here and combined at the end
results_uni   <- list()
results_multi <- list()
results_ph    <- list()

# Run the analysis separately for each study year
for (study_year in years) {

  df <- df_long %>% filter(year==study_year) %>%
    select(-matches("efi|frail"))   # add frailty back when ready

  index_date <- as.Date(paste0(study_year, "-01-01"))   # time zero
  end_date   <- as.Date(paste0(study_year, "-12-31"))   # administrative end of follow-up

  # ---- 2. Covariates and censoring -------------------------------------------
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
      cov_cat_smoking   = relevel(factor(cov_cat_smoking), ref = "N"),

      # Censor at the earliest of death, deregistration or end of year
      censor_date = pmin(end_date, cens_dat_death, cens_dat_dereg, na.rm = TRUE)
    ) %>%
    # Drop raw dates and intermediate variables (outcome dates are kept)
    select(-cov_dat_chd, -cov_dat_hosp, -cov_dat_AE,
           -cov_dat_dem_alz, -cov_dat_dem_vasc, -cov_dat_dem_other,
           -cov_dat_last_med_rev, -months_since_rev,
           -cens_dat_death, -cens_dat_dereg)

  # Run the models for each outcome
  for (outcome in names(outcomes)) {

    message("Running survival analysis for ", outcome, ", ", study_year)

    # ---- 3. Outcome and follow-up --------------------------------------------
    df_outcome <- df %>%
      mutate(
        # Outcome: first event in the study year
        outcome_date = if_else(
          (.data[[outcomes[[outcome]]]] >= index_date) & (.data[[outcomes[[outcome]]]] <= end_date),
          .data[[outcomes[[outcome]]]], as.Date(NA)
        ),

        event     = !is.na(outcome_date) & outcome_date <= censor_date,
        exit_date = if_else(event, outcome_date, censor_date),

        # +1 so an event on 1 Jan has time = 1, not 0
        time = as.numeric(exit_date - index_date) + 1
      )

    # ---- 4. Fit Cox models ---------------------------------------------------
    # Single row per patient (one year), so no clustering needed yet.
    # Add later - I want to add practice ID - add cluster(practice_id);

    # Univariable: one model per predictor
    tbl_uni <- df_outcome %>%
      tbl_uvregression(
        method       = coxph,
        y            = Surv(time, event),
        include      = all_of(predictors),
        exponentiate = TRUE
      )

    # Multivariable: all predictors together
    cox_fit <- df_outcome %>%
      coxph(reformulate(predictors, response = "Surv(time, event)"), data = .)

    tbl_multi <- cox_fit %>%
      tbl_regression(exponentiate = TRUE)

    # Proportional hazards check (Schoenfeld residuals) for the multivariable model.
    # This can fail when there are too few events (e.g. infinite coefficients) -
    # record the failure as an NA GLOBAL row and carry on rather than stopping the script
    ph_table <- tryCatch(
      as.data.frame(cox.zph(cox_fit)$table) %>%
        rownames_to_column("term"),   # one row per predictor, plus GLOBAL
      error = function(e) {
        message("PH check failed for ", outcome, ", ", study_year, ": ", conditionMessage(e))
        tibble(term = "GLOBAL", chisq = NA_real_, df = NA_real_, p = NA_real_)
      }
    )

    result_key <- paste(outcome, study_year)
    results_uni[[result_key]]   <- tidy_cox_table(tbl_uni, study_year) %>%
      mutate(outcome = outcome, .before = year)
    results_multi[[result_key]] <- tidy_cox_table(tbl_multi, study_year) %>%
      mutate(outcome = outcome, .before = year)
    results_ph[[result_key]]    <- ph_table %>%
      mutate(outcome = outcome, year = study_year) %>%
      select(outcome, year, term, chisq, df, p)
  }
}

# ---- 5. Results --------------------------------------------------------------
# All outcomes and years stacked, with outcome and year columns

# Univariable results
bind_rows(results_uni) %>%
  write_csv(here("output", "tables", "cox_univariable.csv"))

# Multivariable results
bind_rows(results_multi) %>%
  write_csv(here("output", "tables", "cox_multivariable.csv"))

# Proportional hazards test results (p < 0.05 suggests the assumption may not hold)
bind_rows(results_ph) %>%
  write_csv(here("output", "tables", "cox_ph_test.csv"))
