# Rounding function for redaction ----
roundmid_any <- function(x, to = 6) {
  # centers on (integer) midpoint of the rounding points
  x <- as.numeric(x)
  ceiling(x / to) * to - (floor(to / 2) * (x != 0))
}

# Function for describing data ----
describe_data <- function(df, name) {
  fs::dir_create(here::here("output/describe/"))
  sink(paste0("output/describe/", name, ".txt"))
  print(skimr::skim(df))
  sink()
  message(paste0("output/describe/", name, ".txt written successfully."))
}