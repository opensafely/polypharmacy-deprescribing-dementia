library(readr)
library(here)
library(dplyr)
library(stringr)
library(fs)
library(purrr)

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
    mutate(n = round(n, -1),
           variable = variable_name) %>%
    rename(value = !!variable_sym)
}

# Using map_dfr to apply across multiple columns and combine rows
count_multiple_categories <- function(df, variable_names) {
  map_dfr(variable_names, ~count_categories(df, .x)) %>%
    relocate(variable, value, n)
}

df_tab1_count <- count_multiple_categories(
  df_dataset,
  c("sex", "region")
)

dir_create(here("output", "tables"))

write_csv(
  df_tab1,
  here("output", "tables", "table1.csv")
)
