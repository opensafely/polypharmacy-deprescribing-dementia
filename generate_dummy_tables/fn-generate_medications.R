generate_medications <- function(
    patients,
    codelist,
    avg_gap_days = 60,
    gap_sd_days = 30,
    stop_prob = 0.05,          # probability of stopping at each step
    restart_prob = 0.3,       # probability of restarting after stopping
    long_gap_prob = 0.05,     # probability of unusually long gap
    start_date = as.Date("2018-01-01"),
    end_date = as.Date("2025-12-31"),
    max_start_offset_days = 500, # max random delay for patient start
    seed = NULL
) {
  if (!is.null(seed)) set.seed(seed)
  
  meds <- list()
  med_id <- 1
  
  for (i in seq_len(nrow(patients))) {
    patient <- patients[i, ]
    
    # Random offset for patient start (simulates entering study later)
    start_offset <- sample(0:max_start_offset_days, 1)
    current_date <- max(start_date + start_offset, patient$date_of_birth)
    
    # Continue generating until we pass end_date
    while (current_date <= end_date) {
      
      # Add prescription
      meds[[med_id]] <- data.frame(
        patient_id = patient$patient_id,
        date = current_date,
        dmd_code = sample(codelist$code, 1),
        consultation_id = sample(1:1e6, 1),
        stringsAsFactors = FALSE
      )
      med_id <- med_id + 1
      
      # Determine gap to next prescription
      gap <- round(rnorm(1, avg_gap_days, gap_sd_days))
      gap <- max(1, gap)
      
      # Occasionally insert long gap
      if (runif(1) < long_gap_prob) {
        gap <- gap + sample(30:180, 1)
      }
      
      # Advance date
      current_date <- current_date + gap
      
      # Occasionally stop prescribing
      if (runif(1) < stop_prob) {
        stopped <- TRUE
        
        # Try restarting after a gap
        if (runif(1) < restart_prob) {
          restart_gap <- sample(30:365, 1)  # restart after 1 month to 1 year
          current_date <- current_date + restart_gap
          stopped <- FALSE
        }
        
        # If not restarting, break the loop for this patient
        if (stopped) break
      }
    }
  }
  
  do.call(rbind, meds)
}
