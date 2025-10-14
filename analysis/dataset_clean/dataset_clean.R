library(readr)
library(here)
library(dplyr)
library(stringr)
library(fs)
library(purrr)

## Define clean dataset output folder ------------------------------------------
print("Creating output/dataset_clean output folder")

dataclean_dir <- "output/dataset_clean/"
dir_create(here::here(dataclean_dir))

## Specify redaction threshold -------------------------------------------------
print("Specify redaction threshold")

## Load dataset
dataset_clean <- read_csv(here("output", "dataset", "input.csv.gz"))

## Create object for flowchart
flow <- data.frame(
  Description = "Input",
  N = nrow(dataset_clean ),
  stringsAsFactors = FALSE
)

## Source functions
lapply(
  list.files("analysis/dataset_clean", full.names = TRUE, pattern = "fn-"),
  source
)

## Modify dummy data
dataset_clean <- modify_dummy(dataset_clean)

## Preprocess the data
dataset_clean <- preprocess(dataset_clean)

## Run quality assurance script
dataset_clean <- qa(dataset_clean)

## Run inclusion and exlcusion criteria
dataset_clean <- inex(dataset_clean, flow)

## Saved cleaned dataset to output folder
write_csv(dataset_clean$input, here::here(dataclean_dir, "input_clean.csv.gz"))

## Saved flowvchart data to output folder
write_csv(dataset_clean$flow, here::here(dataclean_dir, "flow.csv"))
