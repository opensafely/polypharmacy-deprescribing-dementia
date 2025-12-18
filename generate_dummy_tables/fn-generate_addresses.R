generate_addresses <- function(
    patients,
    min_addresses_per_patient = 1,
    max_addresses_per_patient = 3,
    
    ## Stability controls (NEW)
    prob_single_stable_address = 0.85,
    min_stable_address_days = 365,
    
    seed = NULL,
    reference_date = as.Date("2025-12-31")
) {
  if (!is.null(seed)) set.seed(seed)
  
  n_patients <- nrow(patients)
  addresses <- list()
  address_id_counter <- 1
  
  for (i in seq_len(n_patients)) {
    
    patient <- patients[i, ]
    
    ## ---- Most patients: single long, stable address ----
    if (runif(1) < prob_single_stable_address) {
      
      duration_days <- sample(
        min_stable_address_days:(20 * 365),
        1
      )
      
      end_date <- reference_date
      if (!is.na(patient$date_of_death)) {
        end_date <- min(end_date, patient$date_of_death)
      }
      
      start_date <- end_date - duration_days
      start_date <- max(start_date, patient$date_of_birth)
      
      ## Address characteristics
      address_type <- sample(c(0,1,3), 1, prob = c(0.75, 0.15, 0.10))
      rural_urban_classification <- sample(1:8, 1)
      imd_rounded <- sample(seq(0, 32800, by = 100), 1)
      
      imd_quintile <- if (imd_rounded == 0) {
        "unknown"
      } else {
        as.character(pmin(5, ceiling(imd_rounded / 32844 * 5)))
      }
      
      imd_decile <- if (imd_rounded == 0) {
        "unknown"
      } else {
        as.character(pmin(10, ceiling(imd_rounded / 32844 * 10)))
      }
      
      msoa_code <- sprintf("E020%05d", sample(1:99999, 1))
      has_postcode <- sample(c(TRUE, FALSE), 1, prob = c(0.97, 0.03))
      
      care_home_is_potential_match <- sample(c(TRUE, FALSE), 1, prob = c(0.04, 0.96))
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
      next
    }
    
    ## ---- Minority: movers with historical addresses ----
    
    n_addresses <- sample(
      min_addresses_per_patient:max_addresses_per_patient,
      1
    )
    
    start_date <- patient$date_of_birth +
      sample(0:(50 * 365), 1)
    
    for (j in seq_len(n_addresses)) {
      
      duration_days <- sample(30:(15 * 365), 1)
      
      end_date <- start_date + duration_days
      if (!is.na(patient$date_of_death)) {
        end_date <- min(end_date, patient$date_of_death)
      }
      end_date <- min(end_date, reference_date)
      
      address_type <- sample(c(0,1,3), 1, prob = c(0.65, 0.25, 0.10))
      rural_urban_classification <- sample(1:8, 1)
      imd_rounded <- sample(seq(0, 32800, by = 100), 1)
      
      imd_quintile <- if (imd_rounded == 0) {
        "unknown"
      } else {
        as.character(pmin(5, ceiling(imd_rounded / 32844 * 5)))
      }
      
      imd_decile <- if (imd_rounded == 0) {
        "unknown"
      } else {
        as.character(pmin(10, ceiling(imd_rounded / 32844 * 10)))
      }
      
      msoa_code <- sprintf("E020%05d", sample(1:99999, 1))
      has_postcode <- sample(c(TRUE, FALSE), 1, prob = c(0.95, 0.05))
      
      care_home_is_potential_match <- sample(c(TRUE, FALSE), 1, prob = c(0.06, 0.94))
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
      start_date <- end_date + 1
    }
  }
  
  do.call(rbind, addresses)
}
