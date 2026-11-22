## This function applies inclusion/exclusion criteria based on binary
## inex variables and describes the resulting dataset.
## The function will reduce the dataset who fullfill all the following:
# Alive at index
# 65 years or older
# Diagnosed dementia
# Long term antihypertensive users
# Registered for 6 months
# Known sex
# Known IMD
# Known region

inex <- function(input, flow, suffix = "", describe = TRUE) {
  ## Apply exclusion criteria
  print("Apply exclusion criteria")

  all_cols <- colnames(input)
  inex_bin_cols <- c(grep("inex_bin", all_cols, value = TRUE))

  # Loop through binary InEx variables to subset dataset
  for (var in inex_bin_cols) {
    # Subset to TRUE
    input <- subset(input, input[[var]] == TRUE)

    # Add to flow log
    flow <- add_flow_step(flow, description = paste("Inclusion criteria:", var), input = input)
  }

  # Describe data ----
  if (isTRUE(describe)) {
    print("Describe inex data")
    describe_data(df = input, name = "inex", suffix = suffix)
  }
  ## Drop variables that are no longer needed
  input <- input %>% select(-starts_with("inex"))
  
  return(list(input = input, flow = flow))

}
