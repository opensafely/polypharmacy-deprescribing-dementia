# ==============================================================================
# Predictors of time to first medication review, 2017 cohort
# Kaplan-Meier description, univariable and multivariable Cox models
# ==============================================================================

# 1. Setup ---------------------------------------------------------------------
library(tidyverse)   # includes dplyr, readr, tidyr, ggplot2
library(lubridate)
library(survival)
library(gtsummary)
library(broom)
library(here)

source("analysis/utility.R")

dir.create(here("output", "tables"),  recursive = TRUE, showWarnings = FALSE)
dir.create(here("output", "figures"), recursive = TRUE, showWarnings = FALSE)

# Study parameters
study_year <- 2017
index_date <- as.Date("2017-01-01")   # time zero
end_date   <- as.Date("2017-12-31")   # administrative end of follow-up

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
  select(-matches("efi|frail")) %>%   # frailty (EFI) not ready yet: add back later
  mutate(
    across(c(cov_dat_chd, cov_dat_hosp, cov_dat_AE, exp_dat_med_rev), as.Date),
    
    # Baseline status: coded CHD diagnosis before index
    # (AMI, stroke, cancer, hypertension are already binary flags upstream)
    cov_bin_chd_base = !is.na(cov_dat_chd) & cov_dat_chd < index_date,
    
    # Hospital admission / A&E attendance in the 12 months before index
    cov_bin_hosp_12m = in_window_before_index(cov_dat_hosp),
    cov_bin_AE_12m   = in_window_before_index(cov_dat_AE),
    
    # Prior medication review (before index).
    # NOTE: exp_dat_med_rev is the first review of 2017, so it can't be used here.
    # This needs a separate upstream variable holding the most recent review
    # before 1 Jan 2017 (placeholder name below); uncomment once it exists.
    # cov_bin_prior_med_rev = in_window_before_index(cov_dat_prior_med_rev, months = 12),
    
    # Outcome: first medication review in 2017
    # exp_dat_med_rev is already the first review of the year; the window check
    # is a safeguard so out-of-window dates are treated as no event.
    review_date = if_else(
      exp_dat_med_rev >= index_date & exp_dat_med_rev <= end_date,
      exp_dat_med_rev, as.Date(NA)
    ),
    
    # Censoring date: end of year for now.
    # TODO: add death / deregistration dates once available, e.g.
    #   censor_date = pmin(end_date, death_date, dereg_date, na.rm = TRUE)
    censor_date = end_date,
    
    # Event only counts if the review happened before censoring
    event     = !is.na(review_date) & review_date <= censor_date,
    stop_date = if_else(event, review_date, censor_date),
    
    # Follow-up time in days; +1 so a review on 1 Jan has time = 1, not 0
    time = as.numeric(stop_date - index_date) + 1
  ) %>%
  # Drop raw dates so they can't leak into the models
  select(-cov_dat_chd, -cov_dat_hosp, -cov_dat_AE, -exp_dat_med_rev,
         -review_date, -censor_date, -stop_date)

# 5. Prepare model data --------------------------------------------------------
# Check levels() for each factor to confirm the reference categories make sense.
df_model <- df_analysis %>%
  mutate(
    cov_cat_sex       = factor(cov_cat_sex),
    cov_cat_ethnicity = relevel(factor(cov_cat_ethnicity), ref = "White"),
    cov_cat_imd       = factor(cov_cat_imd),                       # check ref is "1 (most deprived)"
    cov_cat_region    = relevel(factor(cov_cat_region), ref = "East"),
    cov_cat_smoking   = factor(cov_cat_smoking)                    # consider setting ref to never-smoker
  )

# Prespecified predictors (defined once, used for all models).
# Dementia is omitted (everyone in the cohort has it) and subtype is left out for now.
# Frailty / EFI to be added back when ready.
predictors <- c(
  "cov_num_age", "cov_cat_sex", "cov_cat_ethnicity", "cov_cat_imd", "cov_cat_region",
  "cov_bin_chd_base", "cov_bin_ami", "cov_bin_stroke", "cov_bin_cancer",
  "cov_bin_hypertension", "cov_num_med_count", "cov_cat_smoking",
  "cov_num_cms", "cov_bin_carehome",
  "cov_bin_hosp_12m", "cov_bin_AE_12m"
  # "cov_bin_prior_med_rev"   # add once the upstream variable exists (see section 4)
)

# 6. Describe time to first review (Kaplan-Meier) ------------------------------
km_fit <- survfit(Surv(time, event) ~ 1, data = df_model)

# Cumulative incidence of review at selected time points
summary(km_fit, times = c(90, 180, 270, 365)) %>%
  {tibble(
    day                   = .$time,
    n_at_risk             = .$n.risk,
    prob_no_review        = .$surv,
    cumulative_incidence  = 1 - .$surv
  )} %>%
  write_csv(here("output", "tables", "km_med_rev.csv"))

# Cumulative incidence curve
tidy(km_fit) %>%
  ggplot(aes(x = time, y = 1 - estimate)) +
  geom_step() +
  geom_ribbon(aes(ymin = 1 - conf.high, ymax = 1 - conf.low), alpha = 0.2) +
  labs(x = "Days since 1 January 2017",
       y = "Cumulative incidence of first medication review") +
  theme_minimal()
ggsave(here("output", "figures", "cuminc_med_rev.png"), width = 7, height = 5)

# 7. Univariable and multivariable Cox models ----------------------------------
# Single row per patient (one year), so no clustering or calendar-year term is
# needed yet. When more years are added: cluster(patient_id) and a year term.

# Univariable: one model per predictor
tbl_uni <- tbl_uvregression(
  df_model,
  method      = coxph,
  y           = Surv(time, event),
  include     = all_of(predictors),
  exponentiate = TRUE
)

# Multivariable: all predictors together
cox_formula <- reformulate(predictors, response = "Surv(time, event)")
cox_fit     <- coxph(cox_formula, data = df_model)
summary(cox_fit)

tbl_multi <- tbl_regression(cox_fit, exponentiate = TRUE)

# 8. Check proportional hazards ------------------------------------------------
ph_test <- cox.zph(cox_fit)
print(ph_test)
# plot(ph_test)   # inspect Schoenfeld residuals for any variables that fail

# 9. Save results --------------------------------------------------------------
# HR > 1 = higher rate of review (shorter time to review) vs the reference group
tbl_merge(
  list(tbl_uni, tbl_multi),
  tab_spanner = c("**Univariable**", "**Multivariable**")
) %>%
  as_gt() %>%
  gt::gtsave(here("output", "tables", "cox_med_rev.html"))

# Plain CSV of multivariable hazard ratios
tidy(cox_fit, exponentiate = TRUE, conf.int = TRUE) %>%
  write_csv(here("output", "tables", "cox_med_rev.csv"))