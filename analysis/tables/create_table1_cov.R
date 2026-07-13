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
df_master <- readr::read_rds(here("output", "dataset_clean", "input_clean_cov.rds"))

#------------------------------------------------
# Create binary indicators for "cov_dat_" variables
#------------------------------------------------
print("Create derived binary variables")
df_master <- df_master %>%
  mutate(across(starts_with("cov_dat_"), ~ !is.na(.x), .names = "{sub('dat', 'bin', .col)}"))

#------------------------------------------------
# Create output directory
#------------------------------------------------
dir.create(here("output", "tables"), recursive = TRUE, showWarnings = FALSE)

#------------------------------------------------
# Initialise list to collect per-year results
#------------------------------------------------
all_years_list <- list()

#================================================
# Loop over years
#================================================
for (year in 2017:2024) {
  
  print(paste0("Processing year: ", year))
  
  df <- df_master
  
  # ---- Create "exposed" variable for medication review ----------------------
  source_col <- paste0("exp_dat_med_rev_", year)
  new_col    <- paste0("exposed_", year)
  
  df[[new_col]] <- !is.na(df[[source_col]])
  
  # ---- Keep only columns for selected year ----------------------------------
  df <- df %>%
    select(
      patient_id,
      matches(paste0("_", year, "$"))
    )
  
  # ---- Remove year suffix from column names ---------------------------------
  names(df) <- names(df) %>%
    str_replace(paste0("_", year, "$"), "")

  
  # ---- Select variables of interest -----------------------------------------
  df <- df %>%
    select(
      patient_id,
      exposed,
      cov_num_age,
      starts_with("cov_cat_"),
      starts_with("cov_bin_"),
      starts_with("strat_cat_")
    ) %>%
    mutate(across(-c(patient_id, exposed, cov_num_age), as.character)) %>%
    mutate(All = "All")
  
  # ---- Convert to long format -----------------------------------------------
  df <- df %>%
    pivot_longer(
      cols      = -c(patient_id, exposed, cov_num_age),
      names_to  = "characteristic",
      values_to = "subcharacteristic"
    )
  
  # ---- Clean missing data ---------------------------------------------------
  df <- df %>%
    mutate(
      subcharacteristic = case_when(
        is.na(subcharacteristic)       ~ "Missing",
        subcharacteristic == ""        ~ "Missing",
        subcharacteristic == "unknown" ~ "Missing",
        TRUE                           ~ as.character(subcharacteristic)
      )
    )
  
  # ---- Calculate median (IQR) age -------------------------------------------
  median_iqr_age <- paste0(
    round(median(df$cov_num_age, na.rm = TRUE), 1), " (",
    round(quantile(df$cov_num_age, 0.25, na.rm = TRUE), 1), "-",
    round(quantile(df$cov_num_age, 0.75, na.rm = TRUE), 1), ")"
  )
  
  # ---- Aggregate counts -----------------------------------------------------
  df <- df %>%
    group_by(characteristic, subcharacteristic) %>%
    summarise(
      N         = n(),
      exposed_N = sum(exposed, na.rm = TRUE),
      .groups   = "drop"
    ) %>%
    mutate(
      N         = as.character(N),
      exposed_N = as.character(exposed_N)
    ) %>%
    arrange(characteristic, subcharacteristic)
  
  # ---- Calculate percentages ------------------------------------------------
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
  
  # ---- Append age row -------------------------------------------------------
  df <- bind_rows(
    df,
    tibble(
      characteristic    = "Age, years",
      subcharacteristic = "Median (IQR)",
      N                 = median_iqr_age
    )
  )
  
  # ---- Add year column and store --------------------------------------------
  all_years_list[[as.character(year)]] <- df %>%
    mutate(year = year, .before = everything())
  
  print(paste0("Year ", year, " complete."))
}

#================================================
# Pool all years
#================================================
print("Pooling all years into combined table")

df_pooled <- bind_rows(all_years_list)

print("Save pooled table to output/tables")
write_csv(df_pooled, here("output", "tables", "table1_cov_all_years.csv"))

#================================================
# Redacted version of pooled table
#================================================
print("Creating redacted version of pooled table")

df_pooled_redacted <- df_pooled %>%
  filter(subcharacteristic != "Median (IQR)") %>%
  group_by(year) %>%
  mutate(
    N_midpoint6_derived = roundmid_any(as.numeric(N)),
    exposed_midpoint6   = roundmid_any(as.numeric(exposed_N))
  ) %>%
  mutate(
    total_N_midpoint6 = N_midpoint6_derived[characteristic == "All"][1],
    percent_midpoint6_derived = if_else(
      characteristic == "All",
      "",
      paste0(round(100 * N_midpoint6_derived / total_N_midpoint6, 1), "%")
    ),
    percent_exposed_midpoint6_derived = if_else(
      N_midpoint6_derived > 0,
      paste0(round(100 * exposed_midpoint6 / N_midpoint6_derived, 1), "%"),
      ""
    )
  ) %>%
  ungroup() %>%
  select(
    year, characteristic, subcharacteristic,
    N_midpoint6_derived, percent_midpoint6_derived,
    exposed_midpoint6, percent_exposed_midpoint6_derived
  ) %>%
  mutate(
    N_midpoint6_derived = as.character(N_midpoint6_derived),
    exposed_midpoint6   = as.character(exposed_midpoint6)
  )

# ---- Re-append age rows (one per year) -------------------------------------
age_rows <- df_pooled %>%
  filter(subcharacteristic == "Median (IQR)") %>%
  select(year, characteristic, subcharacteristic, N_midpoint6_derived = N)

df_pooled_redacted <- bind_rows(df_pooled_redacted, age_rows) %>%
  arrange(year, characteristic, subcharacteristic)

print("Save pooled redacted table to output/tables")
write_csv(df_pooled_redacted, here("output", "tables", "table1_cov_all_years_midpoint6.csv"))


# Derive summary table over full period (2017-2024)
print("Deriving summary table over full period")

# ---- Compute overall median and (IQR) age from underlying data --------------------
print("Computing true median (IQR) age from underlying data")

age_all_years <- map_dfr(2017:2024, function(year) {
  age_col  <- paste0("cov_num_age_", year)
  inex_col <- paste0("inex_bin_all_", year)
  
  if (age_col %in% names(df_master) & inex_col %in% names(df_master)) {
    df_master %>%
      filter(.data[[inex_col]] == TRUE) %>%
      select(patient_id, age = all_of(age_col)) %>%
      mutate(year = year)
  }
})

true_median_iqr_age <- paste0(
  round(median(age_all_years$age, na.rm = TRUE), 1), " (",
  round(quantile(age_all_years$age, 0.25, na.rm = TRUE), 1), "-",
  round(quantile(age_all_years$age, 0.75, na.rm = TRUE), 1), ")"
)

# ---- Aggregate mean N and exposed N across years ---------------------------
df_summary <- df_pooled %>%
  filter(subcharacteristic != "Median (IQR)") %>%
  group_by(characteristic, subcharacteristic) %>%
  summarise(
    mean_N         = mean(as.numeric(N), na.rm = TRUE),
    mean_exposed_N = mean(as.numeric(exposed_N), na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(characteristic, subcharacteristic)

# ---- Recalculate percentages from averaged N values ------------------------
total_mean_N <- df_summary$mean_N[df_summary$characteristic == "All"][1]

df_summary <- df_summary %>%
  mutate(
    mean_percent_of_total = if_else(
      characteristic == "All",
      "",
      paste0(round(100 * mean_N / total_mean_N, 1), "%")
    ),
    mean_percent_exposed = if_else(
      mean_N > 0,
      paste0(round(100 * mean_exposed_N / mean_N, 1), "%"),
      ""
    ),
    mean_N         = as.character(round(mean_N, 1)),
    mean_exposed_N = as.character(round(mean_exposed_N, 1))
  )

# ---- Append true median (IQR) age row --------------------------------------
df_summary <- bind_rows(
  df_summary,
  tibble(
    characteristic    = "Age, years",
    subcharacteristic = "Median (IQR)",
    mean_N            = true_median_iqr_age
  )
)

# ---- Rename columns --------------------------------------------------------
df_summary <- df_summary %>%
  rename(
    "Characteristic"     = "characteristic",
    "Subcharacteristic"  = "subcharacteristic",
    "Mean N"             = "mean_N",
    "Mean N (%)"         = "mean_percent_of_total",
    "Mean Exposed N"     = "mean_exposed_N",
    "Mean Exposed N (%)" = "mean_percent_exposed"
  )

print("Save summary table to output/tables")
write_csv(df_summary, here("output", "tables", "table1_cov_period_summary.csv"))

#================================================
# Redacted / midpoint-rounded version of summary
#================================================
print("Creating redacted version of summary table")

df_summary_redacted <- df_summary %>%
  rename(
    "characteristic"    = "Characteristic",
    "subcharacteristic" = "Subcharacteristic",
    "mean_N"            = "Mean N"
  ) %>%
  filter(subcharacteristic != "Median (IQR)") %>%
  mutate(
    mean_N_midpoint6       = roundmid_any(as.numeric(mean_N)),
    mean_exposed_midpoint6 = roundmid_any(as.numeric(`Mean Exposed N`))
  )

total_mean_N_midpoint6 <- df_summary_redacted$mean_N_midpoint6[
  df_summary_redacted$characteristic == "All"
][1]

df_summary_redacted <- df_summary_redacted %>%
  mutate(
    mean_percent_midpoint6 = if_else(
      characteristic == "All",
      "",
      paste0(round(100 * mean_N_midpoint6 / total_mean_N_midpoint6, 1), "%")
    ),
    mean_percent_exposed_midpoint6 = if_else(
      mean_N_midpoint6 > 0,
      paste0(round(100 * mean_exposed_midpoint6 / mean_N_midpoint6, 1), "%"),
      ""
    ),
    mean_N_midpoint6       = as.character(mean_N_midpoint6),
    mean_exposed_midpoint6 = as.character(mean_exposed_midpoint6)
  ) %>%
  select(
    characteristic, subcharacteristic,
    mean_N_midpoint6, mean_percent_midpoint6,
    mean_exposed_midpoint6, mean_percent_exposed_midpoint6
  )

# ---- Re-append true median (IQR) age row -----------------------------------
df_summary_redacted <- bind_rows(
  df_summary_redacted,
  tibble(
    characteristic    = "Age, years",
    subcharacteristic = "Median (IQR)",
    mean_N_midpoint6  = true_median_iqr_age
  )
)

# ---- Rename columns --------------------------------------------------------
df_summary_redacted <- df_summary_redacted %>%
  rename(
    "Characteristic"                         = "characteristic",
    "Subcharacteristic"                      = "subcharacteristic",
    "Mean N [midpoint6_derived]"             = "mean_N_midpoint6",
    "Mean N (%) [midpoint6_derived]"         = "mean_percent_midpoint6",
    "Mean Exposed N [midpoint6_derived]"     = "mean_exposed_midpoint6",
    "Mean Exposed N (%) [midpoint6_derived]" = "mean_percent_exposed_midpoint6"
  )

print("Save redacted summary table to output/tables")
write_csv(df_summary_redacted, here("output", "tables", "table1_cov_period_summary_midpoint6.csv"))
