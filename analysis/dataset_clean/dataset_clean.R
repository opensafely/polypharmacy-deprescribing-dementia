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

threshold <- 6

## Load dataset
dataset_clean <- read_csv(here("output", "dataset", "input.csv.gz"))

## Create object for flowchart
flow <- data.frame(
  Description = "Input",
  N = nrow(dataset_clean ),
  stringsAsFactors = FALSE
)


## Modify dummy data
source(here::here("analysis", "dataset_clean", "fn-modify_dummy.R"))
dataset_clean <- modify_dummy(dataset_clean)

## Preprocess the data
source(here::here("analysis", "dataset_clean", "fn-preprocess.R"))
dataset_clean <- preprocess(dataset_clean)

## Run quality assurance script
source(here::here("analysis", "dataset_clean", "fn-qa.R"))
dataset_clean <- qa(dataset_clean)

## Run inclusion and exlcusion criteria
source(here::here("analysis", "dataset_clean", "fn-inex.R"))
dataset_clean <- inex(dataset_clean, flow)

## Saved cleaned dataset to output folder
write_csv(dataset_clean$input, here::here(dataclean_dir, "input_clean.csv.gz"))

write_csv(dataset_clean$flow, here::here(dataclean_dir, "flow.csv"))
