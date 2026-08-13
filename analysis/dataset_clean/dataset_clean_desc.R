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
library(jsonlite)

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

dataset_clean <- load_data("input_desc.csv.gz", suffix = "desc", describe = TRUE) 

#load dates
constants <- fromJSON("analysis/config.json")
start_date <- constants$start_date
end_date <- constants$end_date

## Create object for flowchart
flow <- data.frame(
  Description = "Input",
  N = nrow(dataset_clean),
  stringsAsFactors = FALSE
)


## Set reference levels and handle missing values
print("Set reference levels and handle missing values")
dataset_clean <- ref(dataset_clean, suffix = "desc")

## Saved cleaned dataset to output folder
print("Saving cleaned dataset to output folder")

saveRDS(dataset_clean,
        file = here::here(dataclean_dir, "input_clean_desc.rds"),
        compress = TRUE)