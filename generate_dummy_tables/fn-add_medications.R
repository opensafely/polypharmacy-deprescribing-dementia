add_medications <- function(
    medications,
    patients,
    codelist,
    avg_gap_days = 60,
    gap_sd_days = 30,
    stop_prob = 0.05,
    restart_prob = 0.3,
    long_gap_prob = 0.05,
    patient_prevalence = 0.5,
    start_date = as.Date("2018-01-01"),
    end_date = as.Date("2025-12-31"),
    max_start_offset_days = 500,
    seed = NULL
) {
  
  if (!is.null(seed)) set.seed(seed)
  
  meds <- list()
  med_id <- nrow(medications) + 1
  
  for (i in seq_len(nrow(patients))) {
    
    patient <- patients[i, ]
    
    ## ---- NEW: prevalence (some patients never receive this medication) ----
    if (runif(1) > patient_prevalence) {
      next
    }
    
    start_offset <- sample(0:max_start_offset_days, 1)
    current_date <- max(start_date + start_offset, patient$date_of_birth)
    
    if (!is.na(patient$date_of_death)) {
      end_date_i <- min(end_date, patient$date_of_death)
    } else {
      end_date_i <- end_date
    }
    
    while (current_date <= end_date_i) {
      
      meds[[med_id]] <- data.frame(
        patient_id = patient$patient_id,
        date = current_date,
        dmd_code = sample(codelist$code, 1),
        consultation_id = sample(1:1e6, 1),
        stringsAsFactors = FALSE
      )
      med_id <- med_id + 1
      
      gap <- round(rnorm(1, avg_gap_days, gap_sd_days))
      gap <- max(1, gap)
      
      if (runif(1) < long_gap_prob) {
        gap <- gap + sample(30:180, 1)
      }
      
      current_date <- current_date + gap
      
      if (runif(1) < stop_prob) {
        if (runif(1) < restart_prob) {
          restart_gap <- sample(30:365, 1)
          current_date <- current_date + restart_gap
        } else {
          break
        }
      }
    }
  }
  
  if (length(meds) == 0) return(medications)
  
  dplyr::bind_rows(medications, do.call(rbind, meds))
}