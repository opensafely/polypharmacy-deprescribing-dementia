qa <- function(input, flow) {
  # Apply quality assurance to dataset

  # Remove records with missing patient id ----
  print("Remove records with missing patient id")
  input <- input[!is.na(input$patient_id), ]
  flow[nrow(flow) + 1, ] <- c(
    "Quality assurance: Removed records with missing patient id",
    nrow(input)
  )
  # Birth year not in the future
  input <- input[
    !is.na(input$qa_num_birth_year) &
      (input$qa_num_birth_year < format(Sys.Date(),"%Y")),
  ]
  flow[nrow(flow) + 1, ] <- c(
    "Quality assurance: Year of birth must be in the past",
    nrow(input)
  )
  print(flow[nrow(flow), ])

  # Date of death not in the future
  input <- input[
    is.na(input$qa_num_death_year) |
      (input$qa_num_death_year < format(Sys.Date(),"%Y")),
  ]
  flow[nrow(flow) + 1, ] <- c(
    "Quality assurance: Year of death must be in the past",
    nrow(input)
  )
  print(flow[nrow(flow), ])

  # # Known IMD
  # input <- input[
  #   (input$cov_cat_imd != "unknown"),
  # ]
  # flow[nrow(flow) + 1, ] <- c(
  #   "Quality assurance: Known IMD",
  #   nrow(input)
  # )
  # print(flow[nrow(flow), ])

  #Describe data ----
  print("Describe data")

  describe_data(df = input, name = "qa_dataset")

  return(list(input = input, flow = flow))
}
