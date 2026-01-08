library(readr)
library(dplyr)
library(lubridate)

source("generate_dummy_tables/fn-generate_patients.R")
source("generate_dummy_tables/fn-generate_medications.R")
source("generate_dummy_tables/fn-add_medications.R")
source("generate_dummy_tables/fn-generate_decision_support_values.R")
source("generate_dummy_tables/fn-generate_practice_registrations.R")
source("generate_dummy_tables/fn-generate_clinical_events.R")
source("generate_dummy_tables/fn-generate_addresses.R")
source("generate_dummy_tables/fn-generate_emergency_care_attendances.R")
source("generate_dummy_tables/fn-generate_ons_deaths.R")
source("generate_dummy_tables/fn-add_clinical_events.R")


# Load the codelist CSV RUN fn-load_codelists.csv

patients <- generate_patients(
  n_patients = 1000,
  min_age = 0,
  max_age = 110,
  mean_age = 85,
  sd_age = 5,
  sex_probs = c(0.48, 0.48, 0.02, 0.02),
  proportion_dead = 0.15,

  seed = 123
)

## Generate practice registrations
practice_registrations <- generate_practice_registrations(
  patients = patients,
  n_practices = 10,
  max_registrations_per_patient = 3,
  prob_multiple_registrations = 0.4,
  prob_gap = 0.1,
  prob_overlap = 0.05,
  seed = 456
)

# Generate clinical events
clinical_events <- generate_clinical_events(
  patients = patients,
  codelist = dementia_codelist_snomed,
  min_events_per_patient = 0,
  max_events_per_patient = 4,
  numeric_value_mean = 100,
  numeric_value_sd = 20,
  seed = 42
)

snomed_vars <- ls(pattern = "_snomed")
# Loop over each snomed codelist

for (i in seq_along(snomed_vars)) {
  var <- snomed_vars[i]
  codelist <- get(var)
  
  clinical_events <- add_clinical_events(
    clinical_events = clinical_events,
    patients = patients,
    codelist=codelist,
    start_date = as.Date("2014-01-01"),
    end_date = as.Date("2025-12-31"),
    min_events_per_patient = 0,
    max_events_per_patient = 30,
    numeric_value_mean = 50,
    event_prevalence = 0.3, 
    numeric_value_sd = 10
  )
}

clinical_events <- add_clinical_events(
  clinical_events = clinical_events,
  patients = patients,
  codelist=medication_review_codelist_snomed,
  start_date = as.Date("2014-01-01"),
  end_date = as.Date("2025-12-31"),
  min_events_per_patient = 0,
  max_events_per_patient = 30,
  event_prevalence = 0.5, 
  numeric_value_mean = 50,
  numeric_value_sd = 10)

addresses <- generate_addresses(patients, seed = 123)
ons_deaths <- generate_ons_deaths(patients, seed = 123)
decision_support_values <- generate_decision_support_values(patients, n_records_per_patient = 5, seed = 123)

medications <- generate_medications(
  patients = patients,
  codelist = ace_inhibitor_codelist_dmd,
  avg_gap_days = 60,
  gap_sd_days = 30,
  stop_prob = 0.2,
  start_date = as.Date("2014-01-01"),
  end_date = as.Date("2025-12-31"),
  seed = 123
)



# Find all codelists ending in _dmd
dmd_vars <- ls(pattern = "_dmd$")


# Base seed for reproducibility
base_seed <- 123

# Loop over each DMD codelist
for (i in seq_along(dmd_vars)) {
  var <- dmd_vars[i]
  codelist <- get(var)
  
  medications <- add_medications(
    medications=medications,
    patients = patients,
    codelist = codelist,
    avg_gap_days = 30,
    gap_sd_days = 15,
    stop_prob = 0.05,
    restart_prob = 0.5,
    long_gap_prob = 0.2,
    max_start_offset_days = 500,
    start_date = as.Date("2014-01-01"),
    end_date = as.Date("2025-12-31"),
    seed = base_seed + i
  )
}


# Loop over each DMD codelist
for (i in seq_along(dmd_vars)) {
  var <- dmd_vars[i]
  codelist <- get(var)
  
  medications <- add_medications(
    medications=medications,
    patients = patients,
    codelist = codelist,
    avg_gap_days = 20,
    gap_sd_days = 1,
    stop_prob = 0.001,
    restart_prob = 0.2,
    long_gap_prob = 0.001,
    max_start_offset_days = 1,
    start_date = as.Date("2014-01-01"),
    end_date = as.Date("2015-12-31"),
    seed = base_seed + i
  )
}

# apcs
# Output folder
out_dir <- here("dummy_tables")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# Helper function to convert logicals to "T"/"F" (without touching other columns)
convert_logical_to_char <- function(df) {
  logical_cols <- sapply(df, is.logical)
  df[logical_cols] <- lapply(df[logical_cols], function(x) ifelse(x, "T", "F"))
  df
}

clinical_events <- clinical_events[ , setdiff(names(clinical_events), "consultation_id")]

# List of tables to save
tables <- list(
  patients = patients,
  practice_registrations = practice_registrations,
  clinical_events = clinical_events,
  addresses = addresses,
  ons_deaths = ons_deaths,
  decision_support_values = decision_support_values,
  medications = medications
)

# Loop over each table
for(name in names(tables)) {
  df <- tables[[name]]
  
  # Convert logicals to "T"/"F"
  df <- convert_logical_to_char(df)
  
  # NA values written as empty strings
  write.csv(df,
            file = file.path(out_dir, paste0(name, ".csv")),
            row.names = FALSE,
            na = "",
            quote = FALSE)
}
