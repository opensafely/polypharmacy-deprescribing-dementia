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

inex <- function(input, flow) {
  ## Apply exclusion criteria
  print("Apply exclusion criteria")

  all_cols <- colnames(input)
  inex_bin_cols <- c(grep("inex_bin", all_cols, value = TRUE))

  # Loop through binary InEx variables to subset dataset
  for (var in inex_bin_cols) {
    # Subset to TRUE
    input <- subset(input, input[[var]] == TRUE)

    # Add to flow log
    step_name <- paste("Inclusion criteria:", var)
    flow[nrow(flow) + 1, ] <- c(step_name, nrow(input))

    # Print the step result
    print(flow[nrow(flow), ])
  }


  return(list(input = input, flow = flow))

}
