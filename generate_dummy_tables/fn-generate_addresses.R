generate_addresses <- function(
    patients,
    
    # Address duration controls
    mean_address_years = 10,
    min_address_days = 30,
    max_address_days = 30 * 365,
    
    # Gap controls
    prob_gap = 0.05,
    mean_gap_days = 60,
    max_gap_days = 365,
    
    # QA: missingness
    prob_missing_imd = 0.01,
    prob_missing_region = 0.02,   # ~2% missing region
    
    seed = NULL,
    reference_date = as.Date("2025-12-31")
) {
  if (!is.null(seed)) set.seed(seed)
  
  addresses <- list()
  address_id_counter <- 1
  
  # Define region values
  nuts1_regions <- c(
    "North East",
    "North West",
    "Yorkshire and The Humber",
    "East Midlands",
    "West Midlands",
    "East",
    "London",
    "South East",
    "South West"
  )
  
  for (i in seq_len(nrow(patients))) {
    
    patient <- patients[i, ]
    
    # Determine end of follow-up
    end_of_followup <- reference_date
    if (!is.na(patient$date_of_death)) {
      end_of_followup <- min(end_of_followup, patient$date_of_death)
    }
    
    current_date <- patient$date_of_birth
    
    while (current_date < end_of_followup) {
      
      ## ---- 1. Sample address duration (usually long) ----
      duration_days <- ceiling(
        rexp(1, rate = 1 / (mean_address_years * 365))
      )
      duration_days <- min(
        max(duration_days, min_address_days),
        max_address_days
      )
      
      start_date <- current_date
      end_date <- min(start_date + duration_days, end_of_followup)
      
      ## ---- Address characteristics ----
      address_type <- sample(c(0, 1, 3), 1, prob = c(0.7, 0.2, 0.1))
      rural_urban_classification <- sample(1:8, 1)
      
      ## ---- Region (with sparse missingness) ----
      if (runif(1) < prob_missing_region) {
        practice_nuts1_region_name <- NA_character_
      } else {
        practice_nuts1_region_name <- sample(nuts1_regions, 1)
      }
      
      ## ---- IMD (with sparse missingness) ----
      if (runif(1) < prob_missing_imd) {
        imd_rounded <- NA_integer_
        imd_quintile <- "unknown"
        imd_decile <- "unknown"
      } else {
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
      }
      
      msoa_code <- sprintf("E020%05d", sample(1:99999, 1))
      has_postcode <- sample(c(TRUE, FALSE), 1, prob = c(0.97, 0.03))
      
      care_home_is_potential_match <- sample(c(TRUE, FALSE), 1, prob = c(0.05, 0.95))
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
        practice_nuts1_region_name = practice_nuts1_region_name,
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
      
      ## ---- 2. Sample gap (usually zero) ----
      if (runif(1) < prob_gap) {
        gap_days <- ceiling(rexp(1, rate = 1 / mean_gap_days))
        gap_days <- min(gap_days, max_gap_days)
      } else {
        gap_days <- 0
      }
      
      ## ---- 3. Advance time ----
      current_date <- end_date + gap_days + 1
    }
  }
  
  do.call(rbind, addresses)
}
