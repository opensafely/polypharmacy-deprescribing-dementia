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

# Load data
df_dataset <- read_csv(
  here("output", "dataset.csv.gz"),
  col_types = cols(
    latest_dementia_code = col_character(),
    latest_alzheimers_code = col_character(),
    latest_vascular_dementia_code = col_character()
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

df_tab1_counts <- count_multiple_categories(
  df_dataset,
  c("sex", "region", "latest_dementia_code")
)

# Add term descriptions for codes
df_tab1_counts <- df_tab1_counts %>%
  left_join(codelist_dem, by = c("value" = "code"))

dir_create(here("output", "tables"))

write_csv(
  df_tab1_counts,
  here("output", "tables", "table1.csv")
)
