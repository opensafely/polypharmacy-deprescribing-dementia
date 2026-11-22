# Load libraries

library(tidyverse)
library(survival)
library(broom)
library(here)

# Source common functions

print("Source common functions")
source("analysis/utility.R")
source("analysis/tables/fn-cum_inc_functions.R")

# Load data

print("Load cleaned dataset")
# Stopping dates and censoring dates (death, deregistration) both come from the out dataset.
# One row per patient per year, for patients eligible on 1 January of that year.
df <- read_rds(here("output", "dataset_clean", "input_clean_out.rds"))

# Gap sizes for stopping definitions

gap_sizes <- c("90", "120", "180")

# "Stop any": the earliest stop across all drug classes, for each gap size
df <- add_stop_any(df, gap_sizes)

# Output folders
dir.create(here("output", "plots"), recursive = TRUE, showWarnings = FALSE)
dir.create(here("output", "tables"), recursive = TRUE, showWarnings = FALSE)

# ------------------------------------------------------------------------------
# Main loop over gap sizes

for (gap in gap_sizes) {

  print(paste("Processing gap:", gap))

  df_long <- df %>%
    mutate(
      event_date = .data[[paste0("out_dat_stop_any_", gap)]],
      year = as.numeric(year),
      start_date = as.Date(paste0(year, "-01-01")),
      end_date = as.Date(paste0(year, "-12-31"))
    ) %>%
    mutate(
      # Censor at the earliest of death, deregistration or end of year (as in the survival analysis)
      censor_date = pmin(end_date, cens_dat_death, cens_dat_dereg, na.rm = TRUE),
      event = if_else(!is.na(event_date) & event_date <= censor_date, 1, 0),
      time = if_else(
        event == 1,
        as.numeric(event_date - start_date),
        as.numeric(censor_date - start_date)
      )
    )

  # Cumulative incidence summarised weekly, and the midpoint6 rounded version
  weekly_table <- cum_inc_weekly(df_long)
  weekly_table_mid <- cum_inc_weekly_midpoint6(weekly_table)

  # Plots
  plot_obj <- plot_cum_inc(
    weekly_table, "cum_inc",
    title = paste0("Cumulative incidence (", gap, "-day gap)"),
    y_label = "Patients stopping any drug (%)"
  )

  plot_mid <- plot_cum_inc(
    weekly_table_mid, "cum_inc_midpoint6",
    title = paste0("Cumulative incidence (", gap, "-day gap, midpoint6)"),
    y_label = "Patients stopping any drug (%)"
  )

  # ----------------------------------------------------------------------------
  # Save outputs
  # ----------------------------------------------------------------------------

  # standard
  ggsave(
    here("output", "plots", paste0("stop_any_", gap, "_cum_inc.png")),
    plot_obj,
    width = 10,
    height = 6
  )

  write_csv(
    weekly_table %>% select(-date_ref),
    here("output", "tables", paste0("stop_any_", gap, "_cum_inc.csv"))
  )

  # midpoint6
  ggsave(
    here("output", "plots", paste0("stop_any_", gap, "_cum_inc_midpoint6.png")),
    plot_mid,
    width = 10,
    height = 6
  )

  write_csv(
    weekly_table_mid %>% select(-date_ref),
    here("output", "tables", paste0("stop_any_", gap, "_cum_inc_midpoint6.csv"))
  )
}
