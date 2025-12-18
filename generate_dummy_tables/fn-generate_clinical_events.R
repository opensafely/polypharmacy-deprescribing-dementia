generate_clinical_events <- function(
    patients,
    codelist,
    min_events_per_patient = 1,
    max_events_per_patient = 5,
    numeric_value_mean = 50,
    numeric_value_sd = 10,
    reference_date = as.Date("2025-12-31"),
    seed = NULL
) {
  
  if (!is.null(seed)) set.seed(seed)
  
  stopifnot(all(c("patient_id", "date_of_birth") %in% names(patients)))
  stopifnot("snomedct_code" %in% names(codelist))
  
  events <- list()
  event_id <- 1
  consultation_id_counter <- 1
  
  for (i in seq_len(nrow(patients))) {
    
    patient <- patients[i, ]
    
    # How many events for this patient?
    n_events <- sample(min_events_per_patient:max_events_per_patient, 1)
    
    # Earliest and latest possible date
    earliest_date <- patient$date_of_birth
    latest_date <- reference_date
    if (!is.na(patient$date_of_death)) {
      latest_date <- min(latest_date, patient$date_of_death)
    }
    
    if (earliest_date > latest_date) next  # skip impossible
    
    for (j in seq_len(n_events)) {
      
      # Event date
      event_date <- as.Date(runif(1, as.numeric(earliest_date), as.numeric(latest_date)), origin = "1970-01-01")
      
      # Random SNOMED CT code from codelist
      snomedct_code <- sample(codelist$snomedct_code, 1)
      
      # Numeric value
      numeric_value <- rnorm(1, numeric_value_mean, numeric_value_sd)
      
      # Add event
      events[[event_id]] <- data.frame(
        patient_id = patient$patient_id,
        date = event_date,
        snomedct_code = snomedct_code,
        numeric_value = numeric_value,
        consultation_id = consultation_id_counter,
        stringsAsFactors = FALSE
      )
      
      event_id <- event_id + 1
      consultation_id_counter <- consultation_id_counter + 1
    }
  }
  
  clinical_events <- do.call(rbind, events)
  clinical_events
}
