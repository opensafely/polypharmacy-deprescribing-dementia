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
print("Load cleaned dataset")
df <- readr::read_rds(here("output", "dataset_clean", "input_clean_hist.rds"))


#------------------------------------------------
# Create binary indicators for "cov_dat_" variables
#------------------------------------------------
print("Create derived binary variables")
df <- df %>%
  mutate(
    across(starts_with("cov_dat_"), ~ !is.na(.x), .names = "{sub('dat', 'bin', .col)}"))


#------------------------------------------------
# Create "exposed" variable for medication review
#------------------------------------------------
df$exposed <- !is.na(df$exp_dat_med_rev)

#------------------------------------------------
# Select variables of interest (following naming convention)
#------------------------------------------------
print("Select variables of interest")
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
print("Convert to long format")
df <- df %>%
  pivot_longer(
    cols = -c(patient_id, exposed, cov_num_age),
    names_to = "characteristic",
    values_to = "subcharacteristic"
  )

#------------------------------------------------
# Clean missing data
#------------------------------------------------
print("Clean missing data")
df <- df %>%
mutate(
  subcharacteristic = case_when(
    is.na(subcharacteristic) ~ "Missing",
    subcharacteristic == "" ~ "Missing",
    subcharacteristic == "unknown" ~ "Missing",
    TRUE ~ as.character(subcharacteristic)
  )
)

# Calculate median (IQR) age 
print("Calculate median (IQR) age")
median_age <- median(df$cov_num_age, na.rm = TRUE)
iqr_age <- IQR(df$cov_num_age, na.rm = TRUE)
median_iqr_age <- paste0(
  round(median_age, 1), " (", 
  round(quantile(df$cov_num_age, 0.25, na.rm = TRUE), 1), "-",
  round(quantile(df$cov_num_age, 0.75, na.rm = TRUE), 1), ")"
)

#------------------------------------------------
# Aggregate counts
#------------------------------------------------
print("Aggregate counts")
df <- df %>%
  group_by(characteristic, subcharacteristic) %>%
  summarise(
    N = n(),
    exposed_N = sum(exposed, na.rm = TRUE),
    .groups = "drop"
  ) %>%


#Convert N to character to avoid type mismatch
mutate(N = as.character(N), exposed_N = as.character(exposed_N)) %>%

#Sort table
arrange(characteristic, subcharacteristic)

#------------------------------------------------
# Calculate % of total
#------------------------------------------------
print("Calculate percentages")
total_count <- as.numeric(df$N[df$characteristic == "All"][1])

df <- df %>%
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

# Stick them together
df <- bind_rows(
  df,
  tibble(
    characteristic = "Age, years",
    subcharacteristic = "Median (IQR)",
    N = median_iqr_age
  )
)


#------------------------------------------------
# Save
#------------------------------------------------
print("Save table 1 to output/tables")
dir.create(here("output", "tables"), recursive = TRUE, showWarnings = FALSE)
write_csv(df, here("output", "tables", "table_1_hist.csv"))


#------------------------------------------------
# Created redacted / midpoint rounded version
#------------------------------------------------
print("Creating redacted / midpoint rounded version of table 1")

df <- df[df$subcharacteristic != "Median (IQR)", ] # Remove Median IQR row

df$N_midpoint6_derived <- roundmid_any(df$N)
df$exposed_midpoint6 <- roundmid_any(df$exposed_N)


df$percent_midpoint6_derived <- paste0(
  ifelse(
    df$characteristic == "All",
    "",
    paste0(
      round(
        100 *
          (df$N_midpoint6_derived /
            (as.numeric(df[df$characteristic == "All", "N_midpoint6_derived"]))),
        1
      ),
      "%"
    )
  )
)

df$percent_exposed_midpoint6_derived <- paste0(if_else(
      as.numeric(df$N_midpoint6_derived) > 0,
      paste0(round(100 * as.numeric(df$exposed_midpoint6) / as.numeric(df$N_midpoint6_derived), 1), "%"),
      ""
    ))

df <- df[, c(
  "characteristic",
  "subcharacteristic",
  "N_midpoint6_derived",
  "percent_midpoint6_derived",
  "exposed_midpoint6",
  "percent_exposed_midpoint6_derived"
)]

df <- df %>%
  mutate(
    N_midpoint6_derived = as.character(N_midpoint6_derived),
    exposed_midpoint6 = as.character(exposed_midpoint6)
  )

df <- bind_rows(
  df,
  tibble(
    characteristic = "Age, years",
    subcharacteristic = "Median (IQR)",
    N_midpoint6_derived = median_iqr_age
  )
)

df <- dplyr::rename(
  df,
  "Characteristic" = "characteristic",
  "Subcharacteristic" = "subcharacteristic",
  "N [midpoint6_derived]" = "N_midpoint6_derived",
  "(%) [midpoint6_derived]" = "percent_midpoint6_derived",
  "Exposed [midpoint6_derived]" = "exposed_midpoint6",
  "Percent Exposed [midpoint6_derived]" = "percent_exposed_midpoint6_derived"
)

# Save rounded / redacted table
print("Save redacted / midpoint rounded table 1 to output/tables")
write_csv(df, here("output", "tables", "table_1_hist_midpoint6.csv"))
