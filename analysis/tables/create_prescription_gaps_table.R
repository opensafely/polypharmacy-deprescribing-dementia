# Load libraries ---------------------------------------------------------------
library(readr)
library(tidyverse)
library(gtsummary)
library(here)
library(dplyr)

# Source common functions ------------------------------------------------------
print("Source common functions")
source("analysis/utility.R")

#------------------------------------------------
# Load data
#------------------------------------------------
print("Load cleaned dataset")
df <- readr::read_rds(
  here("output", "dataset_clean", "input_clean_hist.rds")
)

#------------------------------------------------
# Summarise counts per region + care home + overall
#------------------------------------------------
region_sums <- df %>%
  # ---- Region summaries ----
  group_by(cov_cat_region) %>%
  summarise(
    across(starts_with("out_num_gap_"), ~ sum(.x, na.rm = TRUE))
  ) %>%
  ungroup() %>%
  mutate(cov_cat_region = as.character(cov_cat_region)) %>%

  # ---- Care home summaries (labelled) ----
  bind_rows(
    df %>%
      group_by(cov_bin_carehome) %>%
      summarise(
        across(starts_with("out_num_gap_"), ~ sum(.x, na.rm = TRUE))
      ) %>%
      ungroup() %>%
      mutate(
        cov_cat_region = case_when(
          cov_bin_carehome == TRUE  ~ "TRUE (Care Home)",
          cov_bin_carehome == FALSE ~ "FALSE (Care Home)"
        )
      ) %>%
      select(-cov_bin_carehome)
  ) %>%

  # ---- Overall summary ----
  bind_rows(
    df %>%
      summarise(
        across(starts_with("out_num_gap_"), ~ sum(.x, na.rm = TRUE))
      ) %>%
      mutate(cov_cat_region = "Overall")
  )

#------------------------------------------------
# Save
#------------------------------------------------
print("Save to output/tables")
dir.create(
  here("output", "tables"),
  recursive = TRUE,
  showWarnings = FALSE
)

write_csv(
  region_sums,
  here("output", "tables", "prescription_gaps.csv")
)
