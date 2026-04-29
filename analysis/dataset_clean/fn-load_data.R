## This function performs the initial loading of the dataset.
# It also performs basic preprocessing to ensure that the data is in the correct
# format for subsequent cleaning steps.

load_data <- function(filename, suffix = "", describe = TRUE) {
  
  # Get column names ----
  print("Get column names")
  file_path <- paste0("output/dataset/", filename)

  all_cols <- fread(
    file_path,
    header = TRUE,
    sep = ",",
    nrows = 0,
    stringsAsFactors = FALSE
  ) %>%
    names()
  message("Column names found")
  print(all_cols)

  # Define column classes ----
  print("Define column classes")

  cat_cols <- c("patient_id", grep("_cat", all_cols, value = TRUE))
  bin_cols <- c(grep("_bin", all_cols, value = TRUE))
  num_cols <- c(grep("_num", all_cols, value = TRUE))
  date_cols <- grep("_dat", all_cols, value = TRUE)

  message("Column classes identified")

  col_classes <- setNames(
    c(
      rep("c", length(cat_cols)),
      rep("l", length(bin_cols)),
      rep("d", length(num_cols)),
      rep("D", length(date_cols))
    ),
    all_cols[match(
      c(cat_cols, bin_cols, num_cols, date_cols),
      all_cols
    )]
  )
  message("Column classes defined")

  # Load cohort dataset ----
  print("Load dataset")

  input <- read_csv(file_path, col_types = col_classes)
  message(paste0(
    "Dataset has been read successfully with N = ",
    nrow(input),
    " rows"
  ))

  #Format dataset columns
  input <- input %>%
    mutate(
      across(all_of(date_cols), ~ floor_date(as.Date(., "%Y-%m-%d"), "days")),
      across(contains("_birth_year"), ~ as.numeric(.)),
      across(all_of(num_cols), ~ as.numeric(.)),
      across(all_of(cat_cols), ~ as.character(.))
    )


  # Describe data ----
  if (isTRUE(describe)) {
    print("Describe preprocessed data")
    describe_data(
      df = input,
      name = paste0(
        "preprocessed",
        if (nzchar(suffix)) paste0("-", suffix) else ""
      )
    )
  }

  return(input)

}
