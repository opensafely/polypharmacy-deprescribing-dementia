inex <- function(input, flow) {
  ## Apply exclusion criteria
  print("Apply exclusion criteria")

  ## Patients must be alive at index.
  input <- subset(input, inex_bin_alive == TRUE)
  flow[nrow(flow) + 1, ] <- c("Inclusion criteria: Alive at index", nrow(input))
  print(flow[nrow(flow), ])

  ## Patients must have been registered for 6 months at index.
  input <- subset(input, inex_bin_6m_reg == TRUE)
  flow[nrow(flow) + 1, ] <- c("Inclusion criteria: Registered for 6 months", nrow(input))
  print(flow[nrow(flow), ])

  # Missing sex
  input <- subset(input, cov_cat_sex == "female" | cov_cat_sex == "male" | cov_cat_sex == "intersex")
  flow[nrow(flow) + 1, ] <- c("Inclusion criteria: Known sex", nrow(input))

  # Missing IMD
  input <- subset(input, cov_cat_imd %in% c("1 (most deprived)", "2", "3", "4", "5 (least deprived)"))
  flow[nrow(flow) + 1, ] <- c("Inclusion criteria: Known IMD", nrow(input))
  print(flow[nrow(flow), ])

  # Missing region
  input <- subset(input, cov_cat_region %in% c(
    "East",
    "East Midlands",
    "London",
    "North East",
    "North West",
    "South East",
    "South West",
    "West Midlands",
    "Yorkshire and The Humber"
  ))
  flow[nrow(flow) + 1, ] <- c("Inclusion criteria: Known region", nrow(input))
  print(flow[nrow(flow), ])

  ## Patients must have dementia diagnosis
  input <- subset(input, inex_bin_has_dem == TRUE)
  flow[nrow(flow) + 1, ] <- c("Inclusion criteria: Diagnosed with dementia", nrow(input)) 
  print(flow[nrow(flow), ])

  ## Patients must be age 65 or older
  input <- subset(input, inex_bin_over_64 == TRUE)
  flow[nrow(flow) + 1, ] <- c("Inclusion criteria: 65 years or older", nrow(input)) 
  print(flow[nrow(flow), ])

  ## Patients must be long term antihypertensive user
  input <- subset(input, inex_bin_antihyp == TRUE)
  flow[nrow(flow) + 1, ] <- c("Inclusion criteria: Long term antihypertensive user", nrow(input)) 
  print(flow[nrow(flow), ])

  #Describe data ----
  print("Describe data")
  describe_data(df = input, name = "inex_dataset")

  return(list(input = input, flow = flow))

}
