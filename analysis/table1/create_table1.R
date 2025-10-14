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
# Select variables of interest (following naming convention)
#------------------------------------------------
df_table1 <- df %>%
  select(
    patient_id,
    starts_with("cov_cat_"),
    starts_with("cov_bin_"),
    starts_with("strat_cat_"),
  )

# Ensure all variables are character type for consistent processing
df_table1 <- df_table1 %>%
  mutate(across(-patient_id, as.character))
# Add a catch-all "All" group (for total counts)
df_table1$All <- "All"

#------------------------------------------------
# Convert to long format: one row per characteristic/subcharacteristic
#------------------------------------------------
df_long <- df_table1 %>%
  pivot_longer(
    cols = -patient_id,
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
    .groups = "drop"
  )

#------------------------------------------------
# Convert N to character to avoid type mismatch
#------------------------------------------------
table1 <- table1 %>%
  mutate(N = as.character(N))


#------------------------------------------------
# Sort and optionally add summary rows
#------------------------------------------------
table1 <- table1 %>%
  arrange(characteristic, subcharacteristic)


#------------------------------------------------
# Calculate % of total
#------------------------------------------------
total_count <- table1 %>% filter(characteristic == "All") %>% pull(N) %>% as.numeric()

table1 <- table1 %>%
  mutate(
    percent_of_total = if_else(
      characteristic == "All" | subcharacteristic == "Median (IQR)",
      "",
      paste0(round(100 * as.numeric(N) / total_count, 1), "%")
    )
  )

# Add a median (IQR) age row if cov_num_age exists
if ("cov_num_age" %in% names(df)) {
  median_age <- median(df$cov_num_age, na.rm = TRUE)
  iqr_age <- IQR(df$cov_num_age, na.rm = TRUE)
  median_iqr_age <- paste0(
    round(median_age, 1), " (", 
    round(quantile(df$cov_num_age, 0.25, na.rm = TRUE), 1), "–",
    round(quantile(df$cov_num_age, 0.75, na.rm = TRUE), 1), ")"
  )

  table1 <- bind_rows(
    table1,
    tibble(
      characteristic = "Age, years",
      subcharacteristic = "Median (IQR)",
      N = median_iqr_age
    )
  )
}

#------------------------------------------------
# Save
#------------------------------------------------
dir.create(here("output", "tables"), recursive = TRUE, showWarnings = FALSE)
write_csv(table1, here("output", "tables", "table1.csv"))