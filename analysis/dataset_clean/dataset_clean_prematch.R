library(readr)
library(here)
library(dplyr)
library(stringr)
library(fs)
library(purrr)
library(lubridate)
library(tidyr)
library(skimr)
library(data.table)
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

## Load dataset
print("Load dataset")
dataset_clean <- load_data("input_prematch.csv.gz", suffix = "prematch", describe = TRUE) 

start_date <- as.Date("2017-01-01")
end_date <- as.Date("2024-12-31")

## Create object for flowchart
flow <- data.frame(
  Description = "Input",
  N = nrow(dataset_clean),
  stringsAsFactors = FALSE
)

## Run quality assurance script
print("Running quality assurance")

# This function returns a list with two elements: input and flow
dataset_clean <- qa(dataset_clean, flow, suffix = "prematch")
flow <- dataset_clean$flow
dataset_clean <- dataset_clean$input

## Run inclusion and exclusion criteria
print("Applying inclusion and exclusion criteria")
dataset_clean <- inex(dataset_clean, flow, suffix = "prematch")

flow <- dataset_clean$flow
dataset_clean <- dataset_clean$input

## Set reference levels and handle missing values
print("Set reference levels and handle missing values")
dataset_clean <- ref(dataset_clean, suffix = "prematch")

## Saved cleaned dataset to output folder
print("Saving cleaned dataset to output folder")
write_csv(dataset_clean, file = here::here(dataclean_dir, "input_clean_prematch.csv.gz"))

## Saved flowchart data to output folder
print("Saving flowchart data to output folder")
write_csv(flow, here::here(dataclean_dir, "flow_prematch.csv"))

## Create midpoint rounded version of flowchart data
print("Creating midpoint rounded flowchart data")

flow_midpoint6 <- flow %>%
  mutate(
    N = roundmid_any(N)
  )

## Save rounded flowchart data
write_csv(
  flow_midpoint6,
  here::here(dataclean_dir, "flow_prematch_midpoint6.csv")
)