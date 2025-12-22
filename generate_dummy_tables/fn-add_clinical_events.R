add_clinical_events <- function(
    clinical_events,
    patients,
    codelist,
    start_date = as.Date("2014-01-01"),
    end_date = as.Date("2025-12-31"),
    min_events_per_patient = 0,
    max_events_per_patient = 30,
    event_prevalence = 1.0,   # NEW: proportion of patients with >=1 event
    numeric_value_mean = 50,
    numeric_value_sd = 10,
    seed = NULL
) {
  
  if (!is.null(seed)) set.seed(seed)
  
  stopifnot(
    all(c("patient_id", "date_of_birth") %in% names(patients)),
    "snomedct_code" %in% names(codelist),
    inherits(start_date, "Date"),
    inherits(end_date, "Date"),
    start_date <= end_date,
    event_prevalence >= 0,
    event_prevalence <= 1
  )
  
  # Start consultation IDs after the max in the existing table
  if ("consultation_id" %in% names(clinical_events)) {
    consultation_id_counter <- max(clinical_events$consultation_id, na.rm = TRUE) + 1
  } else {
    consultation_id_counter <- 1
  }
  
  events <- list()
  event_id <- 1
  
  for (i in seq_len(nrow(patients))) {
    
    patient <- patients[i, ]
    
    # Decide whether this patient ever gets the event
    has_event <- runif(1) < event_prevalence
    if (!has_event) next
    
    # Number of new events for this patient
    n_events <- sample(
      max(1, min_events_per_patient):max_events_per_patient,
      1
    )
    
    # Determine valid event window
    earliest_date <- max(start_date, patient$date_of_birth, na.rm = TRUE)
    latest_date <- end_date
    
    if (!is.na(patient$date_of_death)) {
      latest_date <- min(latest_date, patient$date_of_death)
    }
    
    if (earliest_date > latest_date) next
    
    for (j in seq_len(n_events)) {
      
      # Random event date within window
      event_date <- as.Date(
        runif(
          1,
          as.numeric(earliest_date),
          as.numeric(latest_date)
        ),
        origin = "1970-01-01"
      )
      
      events[[event_id]] <- data.frame(
        patient_id = patient$patient_id,
        date = event_date,
        snomedct_code = sample(codelist$snomedct_code, 1),
        numeric_value = rnorm(1, numeric_value_mean, numeric_value_sd),
        consultation_id = consultation_id_counter,
        stringsAsFactors = FALSE
      )
      
      event_id <- event_id + 1
      consultation_id_counter <- consultation_id_counter + 1
    }
  }
  
  if (length(events) == 0) {
    return(clinical_events)
  }
  
  rbind(clinical_events, do.call(rbind, events))
}
