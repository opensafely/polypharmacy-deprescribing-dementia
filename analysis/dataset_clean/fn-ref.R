ref <- function(input) {

  # Handle missing values in cov_cat_sex ---------------------------------------
  print("Handle missing values in cov_cat_sex")

  if ("cov_cat_sex" %in% names(input)) {
    input$cov_cat_sex <- if_else(
      input$cov_cat_sex %in% c("male", "female", "intersex"),
      input$cov_cat_sex,
      "missing"
    )
    if ("missing" %in% unique(input$cov_cat_sex)) {
      stop("cov_cat_sex contains missing values.")
    }
  }

  # Handle missing values in cov_cat_imd ---------------------------------------
  print("Handle missing values in cov_cat_imd")

  if ("cov_cat_imd" %in% names(input)) {
    input$cov_cat_imd <- if_else(
      input$cov_cat_imd %in%
        c("1 (most deprived)", "2", "3", "4", "5 (least deprived)"),
      input$cov_cat_imd,
      "missing"
    )
    if ("missing" %in% unique(input$cov_cat_imd)) {
      stop("cov_cat_imd contains missing values.")
    }
  }  

  # Handle missing values in cov_cat_ethnicity ---------------------------------

  if ("cov_cat_ethnicity" %in% names(input)) {
    print("Handle missing values in cov_cat_ethnicity")
    input$cov_cat_ethnicity <- if_else(
      input$cov_cat_ethnicity %in% c("1", "2", "3", "4", "5"),
      input$cov_cat_ethnicity,
      "0"
    )
  }

  # Handle missing values in cov_cat_region ---------------------------------

  if ("cov_cat_region" %in% names(input)) {
    print("Handle missing values in cov_cat_region")
    input$cov_cat_region <- if_else(
      input$cov_cat_region %in% c(
        "East",
        "East Midlands",
        "London",
        "North East",
        "North West",
        "South East",
        "South West",
        "West Midlands",
        "Yorkshire and The Humber"
      ),
      input$cov_cat_region,
      "missing"
    )
  }

  # Handle missing values in cov_cat_smoking
  if ("cov_cat_smoking" %in% names(input)) {
    print('Handle missing values in cov_cat_smoking')
    input$cov_cat_smoking <- if_else(
      input$cov_cat_smoking %in% c("E", "N", "S"),
      input$cov_cat_smoking,
      "M"
    )
  }

  # Recode missing values in binary variables as FALSE -------------------------

  print("Recode missing values in binary variables as FALSE")

  input <- input %>%
    mutate(across(contains("_bin_"), ~ ifelse(. == TRUE, TRUE, FALSE))) %>%
    mutate(across(contains("_bin_"), ~ replace_na(., FALSE)))

  # Set reference levels for factors -------------------------------------------
  print("Set reference levels for factors")

  cat_factors <- colnames(input)[grepl("_cat_", colnames(input))]
  input[, cat_factors] <- lapply(
    input[, cat_factors],
    function(x) factor(x, ordered = FALSE)
  )


  # Set reference level for variable: cov_cat_ethnicity --------------------

  if ("cov_cat_ethnicity" %in% names(input)) {
    print("Set reference level for variable: cov_cat_ethnicity")
    levels(input$cov_cat_ethnicity) <- list(
      "Missing" = "0",
      "White" = "1",
      "Mixed" = "2",
      "Asian" = "3",
      "Black" = "4",
      "Other" = "5"
    )
    input$cov_cat_ethnicity <- relevel(input$cov_cat_ethnicity, ref = "White")
  }

  # Set reference level for variable: cov_cat_region ---------------------------
  if ("cov_cat_region" %in% names(input)) {
    print("Set reference level for variable: cov_cat_region")
    input$cov_cat_region <- ordered(
      input$cov_cat_region,
      levels = c(
        "East",
        "East Midlands",
        "London",
        "North East",
        "North West",
        "South East",
        "South West",
        "West Midlands",
        "Yorkshire and The Humber"
      )
    )
  }

  # Set reference level for variable: cov_cat_imd ------------------------------

  if ("cov_cat_imd" %in% names(input)) {
    print("Set reference level for variable: cov_cat_imd")
    input$cov_cat_imd <- ordered(
      input$cov_cat_imd,
      levels = c("1 (most deprived)", "2", "3", "4", "5 (least deprived)")
    )
  }
  # Set reference level for variable: cov_cat_sex ------------------------------

  if ("cov_cat_sex" %in% names(input)) {
    print("Set reference level for variable: cov_cat_sex")
    levels(input$cov_cat_sex) <- list("Female" = "female", "Male" = "male", "Intersex" = "intersex")
    input$cov_cat_sex <- relevel(input$cov_cat_sex, ref = "Female")
  }

  # Set reference level for variable: cov_cat_smoking --------------------------

  if ("cov_cat_smoking" %in% names(input)) {
    print('Set reference level for variable: cov_cat_smoking')
    levels(input$cov_cat_smoking) <- list(
      "Ever smoker" = "E",
      "Missing" = "M",
      "Never smoker" = "N",
      "Current smoker" = "S"
    )
    input$cov_cat_smoking <- ordered(
      input$cov_cat_smoking,
      levels = c("Never smoker", "Ever smoker", "Current smoker", "Missing")
    )
  }

  print("Set reference level for binaries")

  bin_factors <- colnames(input)[grepl("cov_bin_", colnames(input))]
  input[, bin_factors] <- lapply(
    input[, bin_factors],
    function(x) factor(x, levels = c("FALSE", "TRUE"))
  )

  return(input)
}
