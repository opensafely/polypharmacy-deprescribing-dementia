generate_ons_deaths <- function(
    patients,
    match_probability = 0.99,
    seed = NULL
) {
  if (!is.null(seed)) set.seed(seed)
  
  deaths <- list()
  death_id <- 1
  
  # Patients with known date_of_death
  deceased_patients <- patients[!is.na(patients$date_of_death), ]
  
  for (i in seq_len(nrow(deceased_patients))) {
    
    patient <- deceased_patients[i, ]
    
    if (runif(1) <= match_probability) {
      # 99% chance: use patient_id
      deaths[[death_id]] <- data.frame(
        patient_id = patient$patient_id,
        date = patient$date_of_death,
        stringsAsFactors = FALSE
      )
    } else {
      # 1% chance: assign a death to a random fake patient
      deaths[[death_id]] <- data.frame(
        patient_id = max(patients$patient_id) + sample(1:1000, 1),
        date = patient$date_of_death,
        stringsAsFactors = FALSE
      )
    }
    
    death_id <- death_id + 1
  }
  
  ons_deaths <- do.call(rbind, deaths)
  ons_deaths
}