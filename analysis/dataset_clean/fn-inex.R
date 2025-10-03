inex <- function(input, flow) {
  ## Apply exclusion criteria
  print("Apply exclusion criteria")

  ## Patients must be alive at index.
  input <- subset(input, inex_bin_alive == TRUE)
  flow[nrow(flow) + 1, ] <- c("Inclusion criteria: Alive at index", nrow(input))
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
  input <- subset(input, inex_bin_lt_antihyp_user == TRUE)
  flow[nrow(flow) + 1, ] <- c("Inclusion criteria: Long term antihypertensive user", nrow(input)) 
  print(flow[nrow(flow), ])

  return(list(input = input, flow = flow))

}
