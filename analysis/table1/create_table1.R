library(readr)
library(here)
library(dplyr)
library(stringr)
library(purrr)

#------------------------------------------------
# Load data
#------------------------------------------------
df_dataset <- read_csv(
  here("output", "dataset_clean", "dataset_clean.csv.gz"),
  col_types = cols(
    latest_dementia_code = col_character(),
    latest_alzheimers_code = col_character(),
    latest_vascular_dementia_code = col_character(),
    latest_other_dementia_code = col_character(),
    cov_num_age = col_double()   # ensure numeric
  )
)

#------------------------------------------------
# Create dementia flags
#------------------------------------------------
df_dataset <- df_dataset %>%
  mutate(
    has_alz   = str_trim(as.character(latest_alzheimers_code)) != "",
    has_vasc  = str_trim(as.character(latest_vascular_dementia_code)) != "",
    has_other = str_trim(as.character(latest_other_dementia_code)) != ""
  )

alz_patients   <- df_dataset %>% filter(has_alz)   %>% pull(patient_id)
vasc_patients  <- df_dataset %>% filter(has_vasc)  %>% pull(patient_id)
other_patients <- df_dataset %>% filter(has_other) %>% pull(patient_id)

#------------------------------------------------
# Helper functions
#------------------------------------------------

# Continuous variables: mean (SD), rounded to nearest 10
summarise_continuous <- function(df, var, label) {
  m <- round(mean(df[[var]], na.rm = TRUE), -1)
  s <- round(sd(df[[var]], na.rm = TRUE), -1)

  tibble(
    Variable = label,
    Value = "",
    Summary = sprintf("%d (%d)", m, s)
  )
}

# Categorical variables: n (%), rounded to nearest 10
summarise_categorical <- function(df, var, label) {
  total_n <- sum(!is.na(df[[var]]))  # % based on non-missing

  df %>%
    count(!!sym(var)) %>%
    mutate(
      n_rounded = round(n, -1),
      pct_rounded = round(100 * n / total_n, -1),
      Variable = label,
      Value = as.character(!!sym(var)),
      Summary = sprintf("%d (%d%%)", n_rounded, pct_rounded)
    ) %>%
    select(Variable, Value, Summary)
}

# Dementia summary (from subsets), rounded to nearest 10
summarise_dementia <- function(alz_patients, vasc_patients, other_patients, total_n) {
  raw_n <- c(length(unique(alz_patients)),
             length(unique(vasc_patients)),
             length(unique(other_patients)))

  tibble(
    Variable = "Dementia type",
    Value = c("Alzheimer's", "Vascular", "Other"),
    n = raw_n
  ) %>%
    mutate(
      n_rounded = round(n, -1),
      pct_rounded = round(100 * n / total_n, -1),
      Summary = sprintf("%d (%d%%)", n_rounded, pct_rounded)
    ) %>%
    select(Variable, Value, Summary)
}

#------------------------------------------------
# Build Table 1
#------------------------------------------------
total_n <- nrow(df_dataset)

df_age      <- summarise_continuous(df_dataset, "cov_num_age", "Age")
df_sex      <- summarise_categorical(df_dataset, "cov_cat_sex", "Sex")
df_region   <- summarise_categorical(df_dataset, "cov_cat_region", "Region")
df_dementia <- summarise_dementia(alz_patients, vasc_patients, other_patients, total_n)

table1 <- bind_rows(df_age, df_sex, df_region, df_dementia)

#------------------------------------------------
# Save
#------------------------------------------------
write_csv(table1, here("output", "tables", "table1.csv"))
