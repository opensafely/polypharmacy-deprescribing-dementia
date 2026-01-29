## This file will be used to match patients and assign index dates
## For now it is just a placeholder file so that we have the full pipeline

library(readr)
library(here)
library(dplyr)
library(stringr)
library(fs)
library(purrr)
library(lubridate)
library(tidyr)
library(skimr)
library(MatchIt)

source("analysis/utility.R")


## Define clean dataset output folder ------------------------------------------
dataclean_dir <- "output/dataset_clean"
dir_create(here::here(dataclean_dir))

## Load dataset
print("Load dataset")
dataset_clean <- read_csv(here("output", "dataset", "input_match.csv.gz"))

start_date <- as.Date("2015-01-01")
end_date <- as.Date("2020-03-01")

## Set variables up as we need
dataset_clean <- dataset_clean %>%
  mutate(
    exp_dat_med_rev = as.Date(exp_dat_med_rev),
    exposed = if_else(!is.na(exp_dat_med_rev), 1L, 0L),
    index_date = if_else(exposed == 1, exp_dat_med_rev, as.Date(NA))
  )

## Matching process
print("Matching process")

m <- matchit(
  exposed ~ 1,                          # practice-only matching
  data    = dataset_clean,
  method  = "nearest",
  exact   = ~ mat_num_practice_id,
  ratio   = 5,                           # many-to-one (adjust if needed)
  replace = FALSE
)

matched <- match.data(m)

## Assign index dates to unexposed patients
matched <- matched %>%
  group_by(subclass) %>%
  mutate(
    index_date = if_else(
      exposed == 0,
      index_date[exposed == 1][1],
      index_date
    )
  ) %>%
  ungroup()

matched <- matched %>%
  select(-any_of(c("distance", "weights")))

## Saving cleaned dataset to output folder
print("Saving matched dataset to output folder")
write_csv(matched, file = here::here(dataclean_dir, "input_matched.csv"), na = "")


## ------------------------------------------------------------------
## Matching report
## ------------------------------------------------------------------


# Pre-matching counts
n_total <- nrow(dataset_clean)
n_exposed <- sum(dataset_clean$exposed == 1)
n_unexposed <- sum(dataset_clean$exposed == 0)

# Matched counts
n_matched_total <- nrow(matched)
n_matched_exposed <- sum(matched$exposed == 1)
n_matched_unexposed <- sum(matched$exposed == 0)

# Unmatched counts
matched_ids <- matched %>% pull(patient_id) %>% unique()
unmatched <- dataset_clean %>% filter(!patient_id %in% matched_ids)

n_unmatched_total <- nrow(unmatched)
n_unmatched_exposed <- sum(unmatched$exposed == 1)
n_unmatched_unexposed <- sum(unmatched$exposed == 0)

# Controls per exposed (actual matching efficiency)
controls_per_exposed <- matched %>%
  group_by(subclass) %>%
  summarise(
    n_exposed = sum(exposed == 1),
    n_unexposed = sum(exposed == 0),
    .groups = "drop"
  )

summary_controls <- controls_per_exposed %>%
  summarise(
    mean_controls_per_exposed   = mean(n_unexposed),
    median_controls_per_exposed = median(n_unexposed),
    min_controls_per_exposed    = min(n_unexposed),
    max_controls_per_exposed    = max(n_unexposed)
  )

# Combine everything into a single report
matching_report <- tibble(
  metric = c(
    # Pre-matching
    "Total individuals (pre-matching)",
    "Exposed individuals (pre-matching)",
    "Unexposed individuals (pre-matching)",
    
    # Post-matching
    "Total individuals (matched)",
    "Matched exposed individuals",
    "Matched unexposed individuals",
    
    # Unmatched
    "Total unmatched individuals",
    "Unmatched exposed individuals",
    "Unmatched unexposed individuals",
    
    # Matching efficiency
    "Mean controls per exposed",
    "Median controls per exposed",
    "Minimum controls per exposed",
    "Maximum controls per exposed"
  ),
  value = c(
    n_total,
    n_exposed,
    n_unexposed,
    n_matched_total,
    n_matched_exposed,
    n_matched_unexposed,
    n_unmatched_total,
    n_unmatched_exposed,
    n_unmatched_unexposed,
    summary_controls$mean_controls_per_exposed,
    summary_controls$median_controls_per_exposed,
    summary_controls$min_controls_per_exposed,
    summary_controls$max_controls_per_exposed
  )
)

print(matching_report)

write_csv(
  matching_report,
  here::here(dataclean_dir, "matching_report.csv")
)


describe_data(df = matched, name = paste0("match"))

