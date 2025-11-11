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
dataset_clean <- read_csv(here("output", "dataset", "input.csv.gz"))

start_date <- as.Date("2015-01-01")

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

# ## Modify dummy data
# if (Sys.getenv("OPENSAFELY_BACKEND") %in% c("", "expectations")) {
#   dataset_clean <- modify_dummy(dataset_clean)
#   print("Modifying dummy data")
# }

## Preprocess the data
print("Preprocessing dataset")
dataset_clean <- preprocess(dataset_clean)

## Run quality assurance script
print("Running quality assurance")

# This function returns a list with two elements: input and flow
dataset_clean <- qa(dataset_clean, flow)
flow <- dataset_clean$flow
dataset_clean <- dataset_clean$input

## Run inclusion and exclusion criteria
print("Applying inclusion and exclusion criteria")
dataset_clean <- inex(dataset_clean, flow)

flow <- dataset_clean$flow
dataset_clean <- dataset_clean$input

## Set reference levels and handle missing values
print("Set reference levels and handle missing values")
dataset_clean <- ref(dataset_clean)

## Saved cleaned dataset to output folder
print("Saving cleaned dataset to output folder")

saveRDS(dataset_clean,
        file = here::here(dataclean_dir, "input_clean.rds"),
        compress = TRUE)


## Saved flowchart data to output folder
print("Saving flowchart data to output folder")
write_csv(flow, here::here(dataclean_dir, "flow.csv"))
