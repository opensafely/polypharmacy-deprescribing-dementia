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
