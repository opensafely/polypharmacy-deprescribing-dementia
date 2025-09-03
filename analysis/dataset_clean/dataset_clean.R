library(readr)
library(here)
library(dplyr)
library(stringr)
library(fs)
library(purrr)

## Define clean dataset output folder -------------------------------------------
print("Creating output/dataset_clean output folder")

dataclean_dir <- "output/dataset_clean/"
dir_create(here::here(dataclean_dir))

## Specify redaction threshold --------------------------------------------------
print('Specify redaction threshold')

threshold <- 6

## Load dataset
df_dataset <- read_csv(
  here("output", "dataset.csv.gz"))

## Create object for flowchart
flow <- data.frame(
  Description = "Input",
  N = nrow(df_dataset),
  stringsAsFactors = FALSE
)

## Modify dummy data
source(here::here("analysis", "dataset_clean", "fn-modify_dummy.R"))
df_dataset <- modify_dummy(df_dataset)

## Preprocess the data
source(here::here("analysis", "dataset_clean", "fn-preprocess.R"))
df_dataset <- preprocess(df_dataset)

## Run quality assurance script
source(here::here("analysis", "dataset_clean", "fn-qa.R"))
df_dataset <- qa(df_dataset)

## Run inclusion and exlcusion criteria
source(here::here("analysis", "dataset_clean", "fn-inex.R"))
df_dataset <- inex(df_dataset, flow)

## Saved cleaned dataset to output folder
write_csv(df_dataset, here::here(dataclean_dir, "dataset_clean.csv.gz"))

