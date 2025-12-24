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

## Define clean dataset output folder ------------------------------------------
dataclean_dir <- "output/dataset_clean"
dir_create(here::here(dataclean_dir))

## Load dataset
print("Load dataset")
dataset_clean <- read_csv(here("output", "dataset", "input_match.csv.gz"))

start_date <- as.Date("2015-01-01")
end_date <- as.Date("2020-03-01")

##Create index_dates
dataset_clean <- dataset_clean %>%
  mutate(
    exp_dat_med_rev = as.Date(exp_dat_med_rev),
    index_date = coalesce(exp_dat_med_rev, start_date)
  )

## Saving cleaned dataset to output folder
print("Saving matched dataset to output folder")
write_csv(dataset_clean, file = here::here(dataclean_dir, "input_matched.csv"))
