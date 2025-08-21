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
    latest_vascular_dementia_code = col_character(),
    latest_other_dementia_code = col_character()
  )
)

# Step 1: Clean code fields and create sets of patient IDs
df_dataset <- df_dataset %>%
  mutate(
    has_alz = str_trim(as.character(latest_alzheimers_code)) != "",
    has_vasc = str_trim(as.character(latest_vascular_dementia_code)) != "",
    has_other = str_trim(as.character(latest_other_dementia_code)) != ""
  )

alz_patients <- df_dataset %>% filter(has_alz) %>% pull(patient_id)
vasc_patients <- df_dataset %>% filter(has_vasc) %>% pull(patient_id)
other_patients <- df_dataset %>% filter(has_other) %>% pull(patient_id)

# Step 2: Create dementia counts using patient ID sets
df_dementia_counts <- tibble(
  variable = "dementia_type",
  value = c("Alzheimer's", "Vascular", "Other"),
  n = c(
    length(unique(alz_patients)),
    length(unique(vasc_patients)),
    length(unique(other_patients))
  )
) %>%
  mutate(n = round(n, -1))  # Round to nearest 10


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
      min = min(!!variable_sym, na.rm = TRUE),
      max = max(!!variable_sym, na.rm = TRUE),
      mean = mean(!!variable_sym, na.rm = TRUE)
    )
}

# Calculate descriptive stats for age
df_tab1_stats <- calc_stats(df_dataset, "cov_num_age")

# Calculate counts for sex, region, and dementia codes
df_tab1_counts <- count_multiple_categories(
  df_dataset,
  c("cov_cat_sex", "cov_cat_region")
)

# Add term descriptions for codes
# df_tab1_counts <- df_tab1_counts %>%
#  left_join(codelist_dem, by = c("value" = "code"))

# Combine table with descriptive stats and counts
df_tab1 <- bind_rows(df_tab1_stats, df_tab1_counts, df_dementia_counts)

dir_create(here("output", "tables"))

write_csv(
  df_tab1,
  here("output", "tables", "table1.csv")
)
