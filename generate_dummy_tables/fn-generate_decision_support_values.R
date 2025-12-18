generate_decision_support_values <- function(
    patients,
    n_records_per_patient = 1,
    start_date = as.Date("2010-01-01"),
    end_date = as.Date("2025-12-31"),
    seed = NULL
) {
  if (!is.null(seed)) set.seed(seed)
  
  records <- list()
  record_id <- 1
  
  for (i in seq_len(nrow(patients))) {
    patient <- patients[i, ]
    n_records <- sample(1:n_records_per_patient, 1)
    
    for (j in seq_len(n_records)) {
      calc_date <- sample(seq.Date(start_date, end_date, by = "day"), 1)
      numeric_value <- round(runif(1, 0, 1), 3)  # eFI score 0–1
      records[[record_id]] <- data.frame(
        patient_id = patient$patient_id,
        calculation_date = calc_date,
        numeric_value = numeric_value,
        algorithm_description = "UK Electronic Frailty Index (eFI)",
        algorithm_version = "1.0",
        stringsAsFactors = FALSE
      )
      record_id <- record_id + 1
    }
  }
  
  do.call(rbind, records)
}
