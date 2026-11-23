## Cleans the yearly inex datasets.
## For each study year, reads output/dataset/input_inex_<year>.csv.gz, applies QA and
## inclusion / exclusion criterion, and saves the eligible patients output/dataset_clean/input_clean_inex_<year>.csv.gz.
## Creates inex flowchart output

library(readr)
library(here)
library(dplyr)
library(fs)
library(lubridate)
library(tidyr)
library(data.table)

## Get arguments passed in by yaml
args <- commandArgs(trailingOnly = TRUE)
describe <- if (length(args) >= 1) as.logical(args[1]) else TRUE
stopifnot(!is.na(describe))

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

## Clean each year -------------------------------------------------------------
flows <- list()
eligible <- list()

for (yr in years) {
  print(paste("Cleaning inex dataset for", yr))

  dataset_clean <- load_data(paste0("input_inex_", yr, ".csv.gz"), describe = FALSE)

  ## Create object for flowchart
  flow <- data.frame(
    Description = "Input",
    N = nrow(dataset_clean),
    stringsAsFactors = FALSE
  )

  ## Run quality assurance script (returns a list with two elements: input and flow)
  dataset_clean <- qa(dataset_clean, flow, describe = FALSE)
  flow <- dataset_clean$flow
  dataset_clean <- dataset_clean$input

  ## Run inclusion and exclusion criteria
  dataset_clean <- inex(dataset_clean, flow, describe = FALSE)
  flow <- dataset_clean$flow
  dataset_clean <- dataset_clean$input

  ## Set reference levels and handle missing values
  dataset_clean <- ref(dataset_clean, describe = FALSE)

  ## Save the eligible patients for this year
  write_csv(dataset_clean, file = here::here(dataclean_dir, paste0("input_clean_inex_", yr, ".csv.gz")))

  flows[[as.character(yr)]] <- flow %>% mutate(year = yr, N = as.numeric(N))
  if (isTRUE(describe)) {
    eligible[[as.character(yr)]] <- dataset_clean %>% mutate(year = yr, .after = patient_id)
  }
}

## Describe the eligible patients across all years ------------------------------
if (isTRUE(describe)) {
  describe_data(df = bind_rows(eligible), name = "inex")
}

## Flow chart: one row per step, one column per year ----------------------------
print("Saving flowchart data to output folder")

flow <- bind_rows(flows) %>%
  pivot_wider(names_from = year, values_from = N)

write_csv(flow, here::here(dataclean_dir, "flow_inex.csv"))

## Create midpoint rounded version of flowchart data
print("Creating midpoint rounded flowchart data")

flow_midpoint6 <- flow %>%
  mutate(across(-Description, roundmid_any))

write_csv(flow_midpoint6, here::here(dataclean_dir, "flow_inex_midpoint6.csv"))
