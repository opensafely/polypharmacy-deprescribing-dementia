# Load libraries ---------------------------------------------------------------
library(readr)
library(tidyverse)
library(gtsummary)
library(here)
library(dplyr)

# Source common functions ------------------------------------------------------
print("Source common functions")
source("analysis/utility.R")

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
  mutate(
    across(starts_with("cov_dat_"), ~ !is.na(.x), .names = "{sub('dat', 'bin', .col)}"))


#------------------------------------------------
# Create "exposed" variable for medication review
#------------------------------------------------
df$exposed <- !is.na(df$exp_date_med_rev)

#------------------------------------------------
# Select variables of interest (following naming convention)
#------------------------------------------------
df <- df %>%
  select(
    patient_id,
    exposed,
    cov_num_age,
    starts_with("cov_cat_"),
    starts_with("cov_bin_"),
    starts_with("strat_cat_")
  ) %>%
  mutate(across(-c(patient_id, exposed,cov_num_age), as.character)) %>%
  mutate(All = "All")


#------------------------------------------------
# Convert to long format: one row per characteristic/subcharacteristic
#------------------------------------------------
df <- df %>%
  pivot_longer(
    cols = -c(patient_id, exposed,cov_num_age),
    names_to = "characteristic",
    values_to = "subcharacteristic"
  ) %>%

#------------------------------------------------
# Clean missing data
#------------------------------------------------

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
table1 <- df %>%
  group_by(characteristic, subcharacteristic) %>%
  summarise(
    N = n(),
    exposed_N = sum(exposed, na.rm = TRUE),
    .groups = "drop"
  ) %>%


  # Convert N to character to avoid type mismatch
  mutate(N = as.character(N), exposed_N = as.character(exposed_N)) %>%
  
  #Sort table
  arrange(characteristic, subcharacteristic)

#------------------------------------------------
# Calculate % of total
#------------------------------------------------
total_count <- as.numeric(table1$N[table1$characteristic == "All"][1])

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
  round(quantile(df$cov_num_age, 0.25, na.rm = TRUE), 1), "-",
  round(quantile(df$cov_num_age, 0.75, na.rm = TRUE), 1), ")"
)

# Stick them together
table1 <- bind_rows(
  table1,
  tibble(
    characteristic = "Age, years",
    subcharacteristic = "Median (IQR)",
    N = median_iqr_age
  )
)


#------------------------------------------------
# Save
#------------------------------------------------
dir.create(here("output", "tables"), recursive = TRUE, showWarnings = FALSE)
write_csv(table1, here("output", "tables", "table1.csv"))


#------------------------------------------------
# Created redacted / midpoint rounded version
#------------------------------------------------
print("Creating redacted / midpoint rounded version of table 1")

table1 <- table1[table1$subcharacteristic != "Median (IQR)", ] # Remove Median IQR row

table1$total_midpoint6 <- roundmid_any(table1$N)
table1$exposed_midpoint6 <- roundmid_any(table1$exposed_N)

table1$N_midpoint6_derived <- table1$total_midpoint6

table1$percent_midpoint6_derived <- paste0(
  ifelse(
    table1$characteristic == "All",
    "",
    paste0(
      round(
        100 *
          (table1$total_midpoint6 /
            table1[table1$characteristic == "All", "total_midpoint6"]),
        1
      ),
      "%"
    )
  )
)

table1 <- table1[, c(
  "characteristic",
  "subcharacteristic",
  "N_midpoint6_derived",
  "percent_midpoint6_derived",
  "exposed_midpoint6"
)]

table1 <- bind_rows(
  table1,
  tibble(
    characteristic = "Age, years",
    subcharacteristic = "Median (IQR)",
    N = median_iqr_age
  )
)

table1 <- dplyr::rename(
  table1,
  "Characteristic" = "characteristic",
  "Subcharacteristic" = "subcharacteristic",
  "N [midpoint6_derived]" = "N_midpoint6_derived",
  "(%) [midpoint6_derived]" = "percent_midpoint6_derived",
  "COVID-19 diagnoses [midpoint6]" = "exposed_midpoint6"
)

# Save rounded / redacted table
write_csv(table1, here("output", "tables", "table1_midpoint6.csv"))

