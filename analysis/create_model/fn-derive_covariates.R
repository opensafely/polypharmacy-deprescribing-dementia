derive_covariates <- function(input) {
  input <- input %>%
    mutate(
      cov_num_days_since_AE = as.numeric(index_date - cov_dat_AE),
      cov_num_days_since_hosp = as.numeric(index_date - cov_dat_hosp),
      cov_num_days_since_dem = as.numeric(index_date - cov_dat_dem)
    )
  return(input)
}