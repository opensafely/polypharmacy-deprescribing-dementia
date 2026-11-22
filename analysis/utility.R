# Rounding function for redaction ----
roundmid_any <- function(x, to = 6) {
  # centers on (integer) midpoint of the rounding points
  x <- as.numeric(x)
  ceiling(x / to) * to - (floor(to / 2) * (x != 0))
}

# Function for describing data ----
# Writes output/describe/<name>.txt, or <name>-<suffix>.txt if a suffix is given
describe_data <- function(df, name, suffix = "") {
  if (nzchar(suffix)) name <- paste0(name, "-", suffix)
  fs::dir_create(here::here("output/describe/"))
  sink(paste0("output/describe/", name, ".txt"))
  print(skimr::skim(df))
  sink()
  message(paste0("output/describe/", name, ".txt written successfully."))
}

# Study years: every calendar year from start_date to end_date in analysis/config.json
# (the same years create_project_yaml.py generates the yearly actions for)
get_study_years <- function() {
  config <- jsonlite::fromJSON("analysis/config.json")
  lubridate::year(as.Date(config$start_date)):lubridate::year(as.Date(config$end_date))
}

# Adds a step to the flow chart table: the step description and the number of patients left, and prints it
add_flow_step <- function(flow, description, input) {
  flow[nrow(flow) + 1, ] <- c(description, nrow(input))
  print(flow[nrow(flow), ])
  flow
}

# TRUE if a date falls in the `months` before the index date
in_window_before_index <- function(date, index_date, months = 12) {
  !is.na(date) & (date < index_date) & (date >= (index_date %m-% months(months)))
}

# Tidy a gtsummary regression table body into one row per level for output CSVs
tidy_cox_table <- function(tbl, study_year) {
  tbl$table_body %>%
    mutate(estimate = if_else(reference_row %in% TRUE, 1, estimate)) %>%   # reference level HR = 1
    filter(!(header_row %in% TRUE)) %>%   # drop variable header rows
    mutate(year = study_year) %>%
    select(year, variable, label, estimate, conf.low, conf.high, p.value)
}