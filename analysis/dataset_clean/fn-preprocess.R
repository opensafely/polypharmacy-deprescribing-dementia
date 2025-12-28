preprocess <- function(df) {
  df_dataset <- df
  # Get column names ----
  print("Get column names")
  all_cols <- colnames(df)

  message("Column names found")
  print(all_cols)

  # Define column classes ----
  print("Define column classes")

  cat_cols <- c("patient_id", grep("_cat", all_cols, value = TRUE))
  bin_cols <- c(grep("_bin", all_cols, value = TRUE))
  num_cols <- c(grep("_num", all_cols, value = TRUE))
  date_cols <- grep("_dat", all_cols, value = TRUE)

  message("Column classes identified")

  #Define column classes
  col_classes <- setNames(
    c(
      rep("c", length(cat_cols)),  # characters
      rep("l", length(bin_cols)),  # logicals
      rep("d", length(num_cols)),  # doubles (numeric)
      rep("D", length(date_cols))  # dates
    ),
    all_cols[match(
      c(cat_cols, bin_cols, num_cols, date_cols),
      all_cols
    )]
)

  #Format dataset columns
  df <- df %>%
    mutate(
      across(all_of(date_cols), ~ floor_date(as.Date(., "%Y-%m-%d"), "days")),
      across(contains("_birth_year"), ~ as.numeric(.)),
      across(all_of(num_cols), ~ as.numeric(.)),
      across(all_of(cat_cols), ~ as.character(.))
    )

  return(df)

}
