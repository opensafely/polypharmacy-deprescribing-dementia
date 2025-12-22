library(readr)
library(here)
library(dplyr)
library(stringr)
library(fs)
library(purrr)
library(lubridate)
library(tidyr)
library(skimr)


source("analysis/create_model/fn-calculate_outcomes.R")
source("analysis/create_model/fn-derive_covariates.R")


print("Load cleaned dataset")
df <- readr::read_rds(here("output", "dataset_clean", "input_clean.rds"))

df <- df %>%
  select(-starts_with("out_num_gap"))

df <- calculate_outcomes(df, 30)

df <- df %>%
  select(-starts_with("out_dat"),-starts_with("exp_dat"),-starts_with("gap"))

df <- derive_covariates(df)
bad_factors <- df %>%
  select(
      exp_bin_med_rev ,
      cov_cat_sex ,
      cov_cat_ethnicity ,
      cov_cat_imd ,
      cov_cat_region ,
      cov_num_days_since_dem ,
      cov_bin_dem_vasc ,
      cov_bin_dem_other ,
      cov_bin_ami ,
      cov_dat_chd ,
      cov_bin_cancer ,
      cov_bin_hypertension ,
      cov_bin_carehome ,
      cov_num_med_count ,
      cov_num_days_since_hosp ,
      cov_num_days_since_AE ,
      cov_num_latest_efi
  ) %>%
  summarise(across(everything(), ~ n_distinct(., na.rm = TRUE)))

df <- df %>%
  mutate(
    cov_num_days_since_hosp = as.numeric(as.character(cov_num_days_since_hosp)),
    cov_num_days_since_AE   = as.numeric(as.character(cov_num_days_since_AE))
  )

# Fit the logistic regression model
model <- glm(
  out_bin_stopped_acei ~ exp_bin_med_rev +
    cov_cat_sex +
    cov_cat_ethnicity +
    cov_cat_imd +
    cov_cat_region +
    cov_num_days_since_dem +
    cov_bin_dem_vasc +
    cov_bin_dem_other +
    cov_bin_ami +
    cov_dat_chd +
    cov_bin_cancer +
    cov_bin_hypertension +
    cov_bin_carehome +
    cov_num_med_count +
    cov_num_latest_efi,
  df,
  family = binomial(link = "logit")
)

summary (model)
# -------- Save the model output --------
model_out <- as.data.frame(summary(model)$coefficients)


# readr::write_csv(
#   model_out,
#   here::here("output", "tables", "model_outputs.csv")
# )


dir.create(here("output", "tables"), recursive = TRUE, showWarnings = FALSE)
write_csv(model_out, here("output", "tables", "model_outputs.txt"))