library(readr)
library(tidyverse)
library(gtsummary)
library(here)
library(dplyr)

#------------------------------------------------
# Load data
#------------------------------------------------
df <- read_csv(
  here("output", "dataset_clean", "input_clean.csv.gz"),
  show_col_types = FALSE
)

# Create a variable for 'died during study'
df <- df %>%
  mutate(
    died_during_study = !is.na(qa_num_death_year)
  )

# Select variables for table
df_table1 <- df %>%
  select(
    cov_num_age,
    cov_cat_sex,
    cov_bin_carehome,
    died_during_study
  )

# Create a descriptive Table 1 --------------------------------------------
summary_df <- df_table1 %>%
  summarise(
    n = n(),
    mean_age = mean(cov_num_age, na.rm = TRUE),
    sd_age = sd(cov_num_age, na.rm = TRUE),
    female = sum(cov_cat_sex == "female", na.rm = TRUE),
    male = sum(cov_cat_sex == "male", na.rm = TRUE),
    carehome_resident = sum(cov_bin_carehome == TRUE, na.rm = TRUE),
    died = sum(died_during_study == TRUE, na.rm = TRUE)
  )

#------------------------------------------------
# Save
#------------------------------------------------
dir.create("output/tables", recursive = TRUE, showWarnings = FALSE)
write_csv(summary_df, here("output", "tables", "table1.csv"))