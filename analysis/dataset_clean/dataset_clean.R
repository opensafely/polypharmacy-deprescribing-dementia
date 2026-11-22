## Cleans the yearly datasets (cov, out or hist).
## Reads each year's file (output/dataset/input_<type>_<year>.csv.gz), stacks them into one
## dataset with one row per patient per year (with a `year` column), handles missing values and
## factor levels, and saves output/dataset_clean/input_clean_<type>.rds.
##
## Use in project.yaml with the arguments "type" (cov, out or hist) and describe (TRUE or FALSE)
## The study years are read from analysis/config.json.

library(readr)
library(here)
library(dplyr)
library(fs)
library(lubridate)
library(tidyr)
library(data.table)

## Get arguments passed in by yaml 
args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 0) {
  # Defaults if not passed in
  dataset_type <- "cov"
  describe <- TRUE
} else {
  dataset_type <- args[1]
  describe <- if (length(args) >= 2) as.logical(args[2]) else TRUE
}
# stop if args don't make sense typos or whatever
stopifnot(dataset_type %in% c("cov", "out", "hist"), !is.na(describe))

## Source functions
lapply(
  list.files("analysis/dataset_clean", full.names = TRUE, pattern = "fn-"),
  source
)
source("analysis/utility.R")

## Define clean dataset output folder ------------------------------------------
print("Creating output/dataset_clean output folder")

dataclean_dir <- "output/dataset_clean/"
dir_create(here::here(dataclean_dir))

## Study years -----------------------------------------------------------------
years <- get_study_years()

## Load and stack the yearly datasets ------------------------------------------
dataset_clean <- bind_rows(lapply(years, function(yr) {
  print(paste("Load dataset for", yr))
  load_data(paste0("input_", dataset_type, "_", yr, ".csv.gz"), describe = FALSE) %>%
    mutate(year = yr, .after = patient_id)
}))

if (isTRUE(describe)) {
  describe_data(df = dataset_clean, name = "preprocessed", suffix = dataset_type)
}

## Set reference levels and handle missing values
print("Set reference levels and handle missing values")
dataset_clean <- ref(dataset_clean, suffix = dataset_type, describe = describe)

## Saved cleaned dataset to output folder
print("Saving cleaned dataset to output folder")

saveRDS(dataset_clean,
        file = here::here(dataclean_dir, paste0("input_clean_", dataset_type, ".rds")),
        compress = TRUE)
