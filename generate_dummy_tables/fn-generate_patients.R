generate_patients <- function(
    n_patients = 1000,
    
    ## Age distribution (in years)
    min_age = 0,
    max_age = 100,
    mean_age = 65,
    sd_age = 15,
    
    ## Sex distribution (must sum to 1)
    sex_levels = c("female", "male", "intersex", "unknown"),
    sex_probs  = c(0.49, 0.49, 0.01, 0.01),
    
    ## Mortality
    proportion_dead = 0.4,
    min_death_age = 40,
    max_death_age = 100,
    
    ## Reference date for age calculation
    reference_date = as.Date("2030-12-31"),
    
    ## QA edge cases
    n_future_birth = 1,
    n_future_death = 1,
    n_death_before_birth = 1,
    
    seed = NULL
) {
  
  if (!is.null(seed)) {
    set.seed(seed)
  }
  
  stopifnot(
    length(sex_levels) == length(sex_probs),
    abs(sum(sex_probs) - 1) < 1e-6,
    proportion_dead >= 0,
    proportion_dead <= 1
  )
  
  ## Helper: truncated normal sampling
  rtruncnorm <- function(n, mean, sd, min, max) {
    x <- rnorm(n, mean, sd)
    while (any(x < min | x > max)) {
      idx <- which(x < min | x > max)
      x[idx] <- rnorm(length(idx), mean, sd)
    }
    x
  }
  
  ## Generate ages
  ages <- rtruncnorm(
    n = n_patients,
    mean = mean_age,
    sd = sd_age,
    min = min_age,
    max = max_age
  )
  
  ages <- floor(ages)
  
  ## Date of birth (first day of month)
  dob_raw <- reference_date - round(ages * 365.25)
  date_of_birth <- as.Date(format(dob_raw, "%Y-%m-01"))
  
  ## Sex
  sex <- sample(
    sex_levels,
    size = n_patients,
    replace = TRUE,
    prob = sex_probs
  )
  
  ## Death indicator
  is_dead <- rbinom(n_patients, 1, proportion_dead)
  
  ## Death ages
  death_age <- rep(NA_real_, n_patients)
  
  death_age[is_dead == 1] <- rtruncnorm(
    n = sum(is_dead),
    mean = mean(c(min_death_age, max_death_age)),
    sd = (max_death_age - min_death_age) / 6,
    min = min_death_age,
    max = max_death_age
  )
  
  ## Death dates
  date_of_death <- rep(as.Date(NA), n_patients)
  
  death_dates <- date_of_birth + round(death_age * 365.25)
  
  ## --- FIX IS HERE ---
  ## use which() to ignore NAs in the comparison
  future_death_indices <- which(death_dates > reference_date)
  death_dates[future_death_indices] <- death_dates[future_death_indices] - 3652
  ## -------------------
  
  date_of_death[is_dead == 1] <- death_dates[is_dead == 1]
  
  ## ---- Inject QA failures ----
  
  all_ids <- seq_len(n_patients)
  
  ## 1. Birth date in the future (still first of month)
  if (n_future_birth > 0) {
    idx <- sample(all_ids, n_future_birth)
    future_dob <- reference_date + sample(1:365, n_future_birth, replace = TRUE)
    date_of_birth[idx] <- as.Date(format(future_dob, "%Y-%m-01"))
  }
  
  ## 2. Death date in the future
  if (n_future_death > 0) {
    idx <- sample(all_ids, n_future_death)
    date_of_death[idx] <- reference_date + sample(1:365, n_future_death, replace = TRUE)
  }
  
  ## 3. Death date before birth date
  if (n_death_before_birth > 0) {
    idx <- sample(all_ids, n_death_before_birth)
    date_of_death[idx] <- date_of_birth[idx] - sample(1:365, n_death_before_birth, replace = TRUE)
  }
  
  ## Assemble table
  patients <- data.frame(
    patient_id = seq_len(n_patients),
    date_of_birth = date_of_birth,
    sex = sex,
    date_of_death = date_of_death,
    stringsAsFactors = FALSE
  )
  
  patients
}