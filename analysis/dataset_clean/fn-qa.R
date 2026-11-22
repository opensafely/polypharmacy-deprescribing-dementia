qa <- function(input, flow, suffix = "", describe = TRUE) {
  # Apply quality assurance to dataset

  # Remove records with missing patient id ----
  print("Remove records with missing patient id")
  input <- input[!is.na(input$patient_id), ]
  flow <- add_flow_step(flow, description = "Quality assurance: Removed records with missing patient id", input = input)

  # Birth year not in the future
  input <- input[
    !is.na(input$qa_num_birth_year) &
      (input$qa_num_birth_year < format(Sys.Date(),"%Y")),
  ]
  flow <- add_flow_step(flow, description = "Quality assurance: Year of birth must be in the past", input = input)

  # Date of death not in the future
  input <- input[
    is.na(input$qa_num_death_year) |
      (input$qa_num_death_year < format(Sys.Date(),"%Y")),
  ]
  flow <- add_flow_step(flow, description = "Quality assurance: Year of death must be in the past", input = input)

  # Describe data ----
  if (isTRUE(describe)) {
    print("Describe qa data")
    describe_data(df = input, name = "qa", suffix = suffix)
  }
  return(list(input = input, flow = flow))
}
