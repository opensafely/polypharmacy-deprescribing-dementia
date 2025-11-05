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


  #Describe data ----
  print("Describe data")
  describe_data(df = input, name = "inex_dataset")

  return(list(input = input, flow = flow))

}
