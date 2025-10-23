qa <- function(input, flow) {
  # Apply quality assurance to dataset

  # Remove records with missing patient id ----
  print('Remove records with missing patient id')
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
    "Quality assurance: Year of birth is before today",
    nrow(input)
  )
  print(flow[nrow(flow), ])

  # Date of death not in the future
  input <- input[
    !is.na(input$qa_num_death_year) &
      (input$qa_num_death_year < format(Sys.Date(),"%Y")),
  ]
  flow[nrow(flow) + 1, ] <- c(
    "Quality assurance: Year of death is before today",
    nrow(input)
  )
  print(flow[nrow(flow), ])

  # Missing sex
  input <- subset(input, cov_cat_sex == "female" | cov_cat_sex == "male" | cov_cat_sex == "intersex")
    flow[nrow(flow) + 1, ] <- c(
        "Quality assurance: Known sex",
        nrow(input)
    )

  # Missing IMD
    input <- subset(input, cov_cat_imd %in% c("1 (most deprived)", "2", "3", "4", "5 (least deprived)"))
        flow[nrow(flow) + 1, ] <- c(
            "Quality assurance: Known IMD",
            nrow(input)
        )

  return(list(input = input, flow = flow))
}
