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
print("Creating output/dataset_clean output folder")

dataclean_dir <- "output/dataset_clean/"
dir_create(here::here(dataclean_dir))

## Load dataset
print("Load dataset")
dataset_clean <- read_csv(here("output", "dataset", "input_matched_full.csv.gz"))

start_date <- as.Date("2015-01-01")
end_date <- as.Date("2020-03-01")

## Create object for flowchart
flow <- data.frame(
  Description = "Input",
  N = nrow(dataset_clean),
  stringsAsFactors = FALSE
)

## Source functions
lapply(
  list.files("analysis/dataset_clean", full.names = TRUE, pattern = "fn-"),
  source
)

source("analysis/utility.R")


## Preprocess the data
print("Preprocessing dataset")
dataset_clean <- preprocess(dataset_clean, suffix = "matched-full")


## Set reference levels and handle missing values
print("Set reference levels and handle missing values")
dataset_clean <- ref(dataset_clean, suffix = "matched-full")

## Saved cleaned dataset to output folder
print("Saving cleaned dataset to output folder")

saveRDS(dataset_clean,
        file = here::here(dataclean_dir, "input_clean_matched_full.rds"),
        compress = TRUE)