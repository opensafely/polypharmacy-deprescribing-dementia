generate_emergency_care_attendances <- function(
    patients,
    start_date = as.Date("2018-01-01"),
    end_date = as.Date("2025-12-31"),
    attendance_probability = 0.1,   # proportion of patients with any attendance
    max_attendances_per_patient = 3,
    seed = NULL
) {
  
  if (!is.null(seed)) set.seed(seed)
  
  records <- list()
  attendance_id <- 1
  
  for (i in seq_len(nrow(patients))) {
    patient <- patients[i, ]
    
    # Most patients have no attendances
    if (runif(1) > attendance_probability) next
    
    # Number of attendances for this patient
    n_attendances <- sample(1:max_attendances_per_patient, 1)
    
    # Date range for this patient
    date_start <- max(start_date, patient$date_of_birth)
    date_end <- end_date
    if (!is.na(patient$date_of_death)) {
      date_end <- min(date_end, patient$date_of_death)
    }
    
    if (date_start > date_end) next
    
    attendance_dates <- sort(
      sample(seq.Date(date_start, date_end, by = "day"), n_attendances)
    )
    
    for (d in attendance_dates) {
      records[[attendance_id]] <- data.frame(
        patient_id = patient$patient_id,
        id = attendance_id,
        arrival_date = d,
        
        # Plausible placeholder SNOMED codes
        discharge_destination = sample(
          c("306689006", "19712007", "305351004"), 1
        ),
        diagnosis_01 = sample(
          c("404684003", "25064002", "195967001"), 1
        ),
        
        stringsAsFactors = FALSE
      )
      
      attendance_id <- attendance_id + 1
    }
  }
  
  if (length(records) == 0) {
    return(
      data.frame(
        patient_id = integer(),
        id = integer(),
        arrival_date = as.Date(character()),
        discharge_destination = character(),
        diagnosis_01 = character(),
        stringsAsFactors = FALSE
      )
    )
  }
  
  do.call(rbind, records)
}
