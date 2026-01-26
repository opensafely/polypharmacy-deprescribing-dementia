# Load libraries ---------------------------------------------------------------

library(tidyverse)
library(yaml)
library(here)
library(glue)
library(readr)
library(dplyr)

source("analysis/f-create_project_actions.R")

write_project_yaml("project3.yaml","covid")
