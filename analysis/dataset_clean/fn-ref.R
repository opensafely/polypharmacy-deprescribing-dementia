## Handles missing values and sets factor levels / reference levels.
## All categorical variables are unordered factors; the first level is the reference level.

ref <- function(input, suffix = "", describe = TRUE) {

  # Handle missing values in cov_cat_sex ---------------------------------------
  print("Handle missing values in cov_cat_sex")

  if ("cov_cat_sex" %in% names(input)) {
    input$cov_cat_sex <- if_else(
      input$cov_cat_sex %in% c("male", "female"),
      input$cov_cat_sex,
      "missing"
    )
    if ("missing" %in% unique(input$cov_cat_sex)) {
      stop("cov_cat_sex contains missing values.")
    }
  }

  # Handle missing values in cov_cat_imd ---------------------------------------
  print('Handle missing values in cov_cat_imd')

  if ("cov_cat_imd" %in% names(input)) {
    imd_max <- max(
      suppressWarnings(as.integer(sub(" .*", "", unique(input$cov_cat_imd)))),
      na.rm = TRUE
    )
    imd_levels <- c(
      "1 (most deprived)",
      as.character(seq(2, imd_max - 1)),
      sprintf("%i (least deprived)", imd_max)
    )

    input$cov_cat_imd <- if_else(
      input$cov_cat_imd %in%
        imd_levels,
      input$cov_cat_imd,
      "missing"
    )
  }

  # Handle missing values in cov_cat_ethnicity ---------------------------------

  if ("cov_cat_ethnicity" %in% names(input)) {
    print('Handle missing values in cov_cat_ethnicity')
    input$cov_cat_ethnicity <- if_else(
      input$cov_cat_ethnicity %in%
        c(
          # 6 category labels
          "White",
          "Mixed",
          "Asian",
          "Black",
          "Other",
          # 16 category labels
          "Other White",
          "White and African",
          "All other ethnic groups",
          "African",
          "White Irish",
          "Other Mixed",
          "White British",
          "Caribbean",
          "Other Black",
          "White and Caribbean",
          "Other Asian",
          "Chinese",
          "Pakistani",
          "White and Asian",
          "Indian",
          "Bangladeshi"
        ),
      input$cov_cat_ethnicity,
      "Missing"
    )
  }

  # Handle missing values in cov_cat_region ---------------------------------

  region_levels <- c(
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

  if ("cov_cat_region" %in% names(input)) {
    print("Handle missing values in cov_cat_region")
    input$cov_cat_region <- if_else(
      input$cov_cat_region %in% region_levels,
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

  # Helper: set the levels of a factor in the given order, with "missing"
  # added as the last level if any values are missing
  set_levels <- function(x, levels) {
    if ("missing" %in% x) levels <- c(levels, "missing")
    factor(x, levels = levels)
  }

  # Set reference level for variable: cov_cat_ethnicity --------------------

  if ("cov_cat_ethnicity" %in% names(input)) {
    print('Set reference level for variable: cov_cat_ethnicity')
    if ("White British" %in% unique(input$cov_cat_ethnicity)) {
      input$cov_cat_ethnicity <- relevel(
        input$cov_cat_ethnicity,
        ref = "White British"
      )
    } else {
      input$cov_cat_ethnicity <- relevel(input$cov_cat_ethnicity, ref = "White")
    }
  }

  # Set reference level for variable: cov_cat_region ---------------------------
  if ("cov_cat_region" %in% names(input)) {
    print("Set reference level for variable: cov_cat_region")
    input$cov_cat_region <- set_levels(as.character(input$cov_cat_region), region_levels)
  }


  # Set reference level for variable: cov_cat_imd ------------------------------

  if ("cov_cat_imd" %in% names(input)) {
    print('Set reference level for variable: cov_cat_imd')
    input$cov_cat_imd <- set_levels(as.character(input$cov_cat_imd), imd_levels)
  }

  # Set reference level for variable: cov_cat_sex ------------------------------

  if ("cov_cat_sex" %in% names(input)) {
    print("Set reference level for variable: cov_cat_sex")
    input$cov_cat_sex <- factor(
      input$cov_cat_sex,
      levels = c("female", "male"),
      labels = c("Female", "Male")
    )
  }

  # Set reference level for variable: cov_cat_smoking --------------------------

  if ("cov_cat_smoking" %in% names(input)) {
    print('Set reference level for variable: cov_cat_smoking')
    input$cov_cat_smoking <- factor(
      input$cov_cat_smoking,
      levels = c("N", "E", "S", "M"),
      labels = c("Never smoker", "Ever smoker", "Current smoker", "Missing")
    )
  }

  print("Set reference level for binaries")

  bin_factors <- colnames(input)[grepl("cov_bin_", colnames(input))]
  input[, bin_factors] <- lapply(
    input[, bin_factors],
    function(x) factor(x, levels = c("FALSE", "TRUE"))
  )

  # Describe data ----
  if (isTRUE(describe)) {
    print("Describe ref data")
    describe_data(df = input, name = "ref", suffix = suffix)
  }
  return(input)
}
