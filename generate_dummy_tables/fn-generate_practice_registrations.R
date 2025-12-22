generate_practice_registrations <- function(
    patients,
    
    ## Practices
    n_practices = 200,
    
    ## Registrations per patient
    max_registrations_per_patient = 5,
    prob_multiple_registrations = 0.1,
    
    ## Stability controls
    prob_single_stable_registration = 0.9,
    min_stable_registration_days = 365*10,
    
    ## Timing
    min_registration_length_days = 5 * 365,
    max_registration_length_days = 30 * 365,
    
    ## Gaps and overlaps (QA realism)
    prob_gap = 0.05,
    max_gap_days = 180,
    
    prob_overlap = 0.02,
    max_overlap_days = 90,
    
    ## SystmOne rollout
    systmone_start = as.Date("2000-01-01"),
    systmone_end   = as.Date("2020-12-31"),
    
    ## Reference date
    reference_date = as.Date("2025-12-31"),
    
    seed = NULL
) {
  
  if (!is.null(seed)) set.seed(seed)
  
  stopifnot(
    all(c("patient_id", "date_of_birth") %in% names(patients))
  )
  
  ## ---- Practice metadata ----
  
  practice_pseudo_id <- seq_len(n_practices)
  
  practices <- data.frame(
    practice_pseudo_id = practice_pseudo_id,
    practice_stp = sprintf(
      "E540000%02d",
      sample(1:99, n_practices, replace = TRUE)
    ),
    practice_nuts1_region_name = sample(
      c(
        "North East","North West","Yorkshire and The Humber",
        "East Midlands","West Midlands","East",
        "London","South East","South West"
      ),
      n_practices,
      replace = TRUE
    ),
    practice_systmone_go_live_date = as.Date(
      runif(
        n_practices,
        as.numeric(systmone_start),
        as.numeric(systmone_end)
      ),
      origin = "1970-01-01"
    ),
    stringsAsFactors = FALSE
  )
  
  ## ---- Generate registrations ----
  
  registrations <- list()
  reg_id <- 1
  
  for (i in seq_len(nrow(patients))) {
    
    patient <- patients[i, ]
    practice_id <- sample(practice_pseudo_id, 1)
    
    ## ---- Most patients: single long, stable registration ----
    if (runif(1) < prob_single_stable_registration) {
      
      length_days <- sample(
        max(min_stable_registration_days, min_registration_length_days):
          max_registration_length_days,
        1
      )
      
      end_date <- reference_date
      if (!is.na(patient$date_of_death)) {
        end_date <- min(end_date, patient$date_of_death)
      }
      
      start_date <- end_date - length_days
      start_date <- max(start_date, patient$date_of_birth)
      
      registrations[[reg_id]] <- data.frame(
        patient_id = patient$patient_id,
        start_date = start_date,
        end_date = end_date,
        practice_pseudo_id = practice_id,
        stringsAsFactors = FALSE
      )
      
      reg_id <- reg_id + 1
      next
    }
    
    ## ---- Minority: historical movers ----
    
    n_regs <- 1
    if (runif(1) < prob_multiple_registrations) {
      n_regs <- sample(2:max_registrations_per_patient, 1)
    }
    
    start_date <- patient$date_of_birth +
      round(runif(1, 0, 60) * 365.25)
    
    for (j in seq_len(n_regs)) {
      
      practice_id <- sample(practice_pseudo_id, 1)
      
      length_days <- sample(
        min_registration_length_days:max_registration_length_days,
        1
      )
      
      end_date <- start_date + length_days
      
      if (!is.na(patient$date_of_death)) {
        end_date <- min(end_date, patient$date_of_death)
      }
      end_date <- min(end_date, reference_date)
      
      registrations[[reg_id]] <- data.frame(
        patient_id = patient$patient_id,
        start_date = start_date,
        end_date = end_date,
        practice_pseudo_id = practice_id,
        stringsAsFactors = FALSE
      )
      
      reg_id <- reg_id + 1
      
      next_start <- end_date
      
      if (runif(1) < prob_gap) {
        next_start <- next_start + sample(1:max_gap_days, 1)
      }
      
      if (runif(1) < prob_overlap) {
        next_start <- next_start - sample(1:max_overlap_days, 1)
      }
      
      start_date <- next_start
    }
  }
  
  practice_registrations <- do.call(rbind, registrations)
  
  ## ---- Join practice metadata ----
  
  practice_registrations <- merge(
    practice_registrations,
    practices,
    by = "practice_pseudo_id",
    all.x = TRUE
  )
  
  practice_registrations[
    ,
    c(
      "patient_id",
      "start_date",
      "end_date",
      "practice_pseudo_id",
      "practice_stp",
      "practice_nuts1_region_name",
      "practice_systmone_go_live_date"
    )
  ]
}
