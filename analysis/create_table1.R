library(readr)
library(here)
library(dplyr)
library(stringr)
library(fs)
library(purrr)

# Load codelists
codelist_dem  <- read_csv(
  here("codelists", "nhsd-primary-care-domain-refsets-dem_cod.csv"),
  col_types = cols(code = col_character())
)
codelist_vasc <- read_csv(
  here("codelists","nhsd-primary-care-domain-refsets-vascular-dementia-codes.csv"),
  col_types = cols(code = col_character())
)    
codelist_alz <- read_csv(
  here("codelists", "nhsd-primary-care-domain-refsets-alzheimers-disease-dementia-codes.csv"),
  col_types = cols(code = col_character())
)


# Load data
df_dataset <- read_csv(
  here("output", "dataset.csv.gz"),
  col_types = cols(
    latest_dementia_code = col_character(),
    latest_alzheimers_code = col_character(),
    latest_vascular_dementia_code = col_character()
  )
)

df_dataset <- df_dataset %>%
  mutate(
    dementia_type = case_when(
      latest_dementia_code %in% codelist_alz$code ~ "Alzheimer's",
      latest_dementia_code %in% codelist_vasc$code ~ "Vascular",
      !is.na(latest_dementia_code) ~ "Other",
      TRUE ~ NA_character_
    )
  )

# Create function to counts categories of variables
count_categories <- function(df, variable_name) {
  variable_sym <- rlang::sym(variable_name)

  df %>%
    group_by(!!variable_sym) %>%
    count() %>%
    ungroup() %>%
    mutate(n = round(n, -1),
           variable = variable_name) %>%
    rename(value = !!variable_sym)
}

# Using map_dfr to apply across multiple columns and combine rows
count_multiple_categories <- function(df, variable_names) {
  map_dfr(variable_names, ~count_categories(df, .x)) %>%
    relocate(variable, value, n)
}

# Function to calculate min, max, and mean
# Fill with missing values for the other columns so we can combine later
calc_stats <- function(df, variable_name) {
  variable_sym <- rlang::sym(variable_name)

  df %>%
    summarise(
      variable = variable_name,
      value = NA_character_,
      n = NA_real_,
      term = NA_character_,
      min = min(!!variable_sym, na.rm = TRUE),
      max = max(!!variable_sym, na.rm = TRUE),
      mean = mean(!!variable_sym, na.rm = TRUE)
    )
}

# Calculate descriptive stats for age
df_tab1_stats <- calc_stats(df_dataset, "age")

# Calculate counts for sex, region, and dementia codes
df_tab1_counts <- count_multiple_categories(
  df_dataset,
  c("sex", "region", "dementia_type")
)

# Add term descriptions for codes
# df_tab1_counts <- df_tab1_counts %>%
#  left_join(codelist_dem, by = c("value" = "code"))

# Combine table with descriptive stats and counts
df_tab1 <- bind_rows(df_tab1_stats, df_tab1_counts)

dir_create(here("output", "tables"))

write_csv(
  df_tab1,
  here("output", "tables", "table1.csv")
)
