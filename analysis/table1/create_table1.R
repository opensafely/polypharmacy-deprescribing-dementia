library(readr)
library(tidyverse)
library(gtsummary)
library(here)
library(dplyr)
#------------------------------------------------
# Load data
#------------------------------------------------
df <- read_csv(
  here("output", "dataset_clean", "input_clean.csv.gz"),
  show_col_types = FALSE
)

#------------------------------------------------
# Create binary indicators for "cov_dat_" variables
#------------------------------------------------
df <- df %>%
  mutate(across(starts_with("cov_dat_"), ~ !is.na(.x), .names = "cov_bin_from_{.col}"))


#------------------------------------------------
# Create "exposed" variable for medication review
#------------------------------------------------
df$exposed <- !is.na(df$exp_date_medication_review)

#------------------------------------------------
# Select variables of interest (following naming convention)
#------------------------------------------------
df_table1 <- df %>%
  select(
    patient_id,
    exposed,
    starts_with("cov_cat_"),
    starts_with("cov_bin_"),
    starts_with("strat_cat_"),
  )

# Align data types: convert all to character except patient_id
df_table1 <- df_table1 %>%
  mutate(across(-c(patient_id, exposed), as.character))

#------------------------------------------------
# Add a catch-all "All" group (for total counts)
df_table1$All <- "All"

#------------------------------------------------
# Convert to long format: one row per characteristic/subcharacteristic
#------------------------------------------------
df_long <- df_table1 %>%
  pivot_longer(
    cols = -c(patient_id, exposed),
    names_to = "characteristic",
    values_to = "subcharacteristic"
  )

#------------------------------------------------
# Clean missing data
#------------------------------------------------
df_long <- df_long %>%
  mutate(
    subcharacteristic = case_when(
      is.na(subcharacteristic) ~ "Missing",
      subcharacteristic == "" ~ "Missing",
      subcharacteristic == "unknown" ~ "Missing",
      TRUE ~ as.character(subcharacteristic)
    )
  )

#------------------------------------------------
# Aggregate counts
#------------------------------------------------
table1 <- df_long %>%
  group_by(characteristic, subcharacteristic) %>%
  summarise(
    N = n(),
    exposed_N = sum(exposed, na.rm = TRUE),
    .groups = "drop"
  )

#------------------------------------------------
# Convert N to character to avoid type mismatch
#------------------------------------------------
table1 <- table1 %>%
  mutate(N = as.character(N), exposed_N = as.character(exposed_N))


# Sort table
#------------------------------------------------
table1 <- table1 %>%
  arrange(characteristic, subcharacteristic)


#------------------------------------------------
# Calculate % of total
#------------------------------------------------
total_count <- table1 %>% filter(characteristic == "All") %>% pull(N) %>% as.numeric()

table1 <- table1 %>%
  mutate(
    percent_of_total_population = if_else(
      characteristic == "All" | subcharacteristic == "Median (IQR)",
      "",
      paste0(round(100 * as.numeric(N) / total_count, 1), "%")
    ),
    percent_exposed = if_else(
      as.numeric(N) > 0,
      paste0(round(100 * as.numeric(exposed_N) / as.numeric(N), 1), "%"),
      ""
    )
  )

# Add a median (IQR) age row 

median_age <- median(df$cov_num_age, na.rm = TRUE)
iqr_age <- IQR(df$cov_num_age, na.rm = TRUE)
median_iqr_age <- paste0(
  round(median_age, 1), " (", 
  round(quantile(df$cov_num_age, 0.25, na.rm = TRUE), 1), "–",
  round(quantile(df$cov_num_age, 0.75, na.rm = TRUE), 1), ")"
)

# Stick them together
table1 <- bind_rows(
  table1,
  tibble(
    characteristic = "Age, years",
    subcharacteristic = "Median (IQR)",
    N = median_iqr_age,
    percent_of_total = "",
    exposed_N = "",
    percent_exposed = ""
  )
)


#------------------------------------------------
# Save
#------------------------------------------------
dir.create(here("output", "tables"), recursive = TRUE, showWarnings = FALSE)
write_csv(table1, here("output", "tables", "table1.csv"))