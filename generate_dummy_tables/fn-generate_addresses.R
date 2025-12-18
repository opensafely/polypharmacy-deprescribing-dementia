generate_addresses <- function(
    patients,
    min_addresses_per_patient = 1,
    max_addresses_per_patient = 3,
    seed = NULL,
    reference_date = as.Date("2025-12-31")
) {
  if (!is.null(seed)) set.seed(seed)
  
  n_patients <- nrow(patients)
  addresses <- list()
  address_id_counter <- 1
  
  for (i in seq_len(n_patients)) {
    
    patient <- patients[i, ]
    
    # Decide number of addresses for this patient
    n_addresses <- sample(min_addresses_per_patient:max_addresses_per_patient, 1)
    
    start_date <- patient$date_of_birth
    
    for (j in seq_len(n_addresses)) {
      
      # Address type
      address_type <- sample(c(0,1,3), 1, prob = c(0.7, 0.2, 0.1))
      
      # Duration at this address (30 days to 20 years)
      duration_days <- sample(30:(20*365), 1)
      
      end_date <- start_date + duration_days
      if (!is.na(patient$date_of_death)) {
        end_date <- min(end_date, patient$date_of_death)
      }
      end_date <- min(end_date, reference_date)
      
      # Rural/urban classification
      rural_urban_classification <- sample(1:8, 1)
      
      # IMD rank (0–32,800 rounded to 100)
      imd_rounded <- sample(seq(0, 32800, by = 100), 1)
      
      # IMD quintile
      if (imd_rounded == 0) {
        imd_quintile <- "unknown"
      } else {
        imd_quintile <- as.character(
          ceiling(imd_rounded / 32844 * 5)
        )
        imd_quintile[imd_quintile == "6"] <- "5" # handle rounding
      }
      
      # IMD decile
      if (imd_rounded == 0) {
        imd_decile <- "unknown"
      } else {
        imd_decile <- as.character(
          ceiling(imd_rounded / 32844 * 10)
        )
        imd_decile[imd_decile == "11"] <- "10" # handle rounding
      }
      
      # MSOA code
      msoa_code <- sprintf("E020%05d", sample(1:99999, 1))
      
      # Postcode flag
      has_postcode <- sample(c(TRUE,FALSE), 1, prob = c(0.95,0.05))
      
      # Care home flags
      care_home_is_potential_match <- sample(c(TRUE,FALSE), 1, prob = c(0.05,0.95))
      care_home_requires_nursing <- FALSE
      care_home_does_not_require_nursing <- FALSE
      if (care_home_is_potential_match) {
        if (runif(1) < 0.5) {
          care_home_requires_nursing <- TRUE
        } else {
          care_home_does_not_require_nursing <- TRUE
        }
      }
      
      addresses[[address_id_counter]] <- data.frame(
        address_id = address_id_counter,
        patient_id = patient$patient_id,
        start_date = start_date,
        end_date = end_date,
        address_type = address_type,
        rural_urban_classification = rural_urban_classification,
        imd_rounded = imd_rounded,
        imd_quintile = imd_quintile,
        imd_decile = imd_decile,
        msoa_code = msoa_code,
        has_postcode = has_postcode,
        care_home_is_potential_match = care_home_is_potential_match,
        care_home_requires_nursing = care_home_requires_nursing,
        care_home_does_not_require_nursing = care_home_does_not_require_nursing,
        stringsAsFactors = FALSE
      )
      
      address_id_counter <- address_id_counter + 1
      
      # Next start date is day after previous end date
      start_date <- end_date + 1
    }
  }
  
  do.call(rbind, addresses)
}
