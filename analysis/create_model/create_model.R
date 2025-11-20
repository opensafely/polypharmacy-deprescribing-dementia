library(readr)
library(here)
library(dplyr)
library(stringr)
library(fs)
library(purrr)
library(lubridate)
library(tidyr)
library(skimr)


source("analysis/create_model/fn-prepare_model_input.R")

print("Load cleaned dataset")
df <- readr::read_rds(here("output", "dataset_clean", "input_clean.rds"))

df <- calculate_outcomes(df, 30)


# Fit the logistic regression model
model <- glm(
  out_bin_stopped_arb_med ~ exp_bin_review +
    cov_num_age +
    cov_cat_sex +
    cov_cat_ethnicity +
    cov_cat_imd +
    cov_cat_region +
    cov_dat_dem +
    cov_bin_dem_alz +
    cov_bin_dem_vasc +
    cov_bin_dem_other +
    cov_bin_ami +
    cov_bin_stroke_isch +
    cov_dat_chd +
    cov_bin_cancer +
    cov_bin_hypertension +
    cov_bin_carehome +
    cov_cat_smoking +
    cov_num_medication_count +
    cov_dat_hosp +
    cov_dat_AE +
    cov_num_latest_efi,
  data = df_period,
  family = binomial(link = "logit")
)

summary(model)