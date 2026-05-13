# Load libraries 

library(tidyverse)
library(survival)
library(survminer)
library(broom)
library(scales)
library(here)
library(dplyr)
library(readr)

# Source common functions

print("Source common functions")
source("analysis/utility.R")

# Load data

print("Load cleaned dataset")
df <- read_rds(here("output", "dataset_clean", "input_clean_desc.rds"))

# Define drug classes and gap sizes for stopping definitions

drug_classes <- c("acei", "bb", "arb", "aab", "ccb", "caa", "psd")
gap_sizes <- c("30", "90", "180")

# Get years from the dataset based on column names
stop_cols <- names(df) %>%
  str_subset("^desc_dat_stop_")

years <- stop_cols %>%
  str_extract("\\d{4}$") %>%
  unique()

# ------------------------------------------------------------------------------
# Main loop over gap sizes

for (gap in gap_sizes) {

  print(paste("Processing gap:", gap))

  # Create variables variables showing "stop any drug"
  for (yr in years) {

    cols_this_year <- paste0("desc_dat_stop_", drug_classes, "_", gap, "_", yr)

    # Handles case when there are no columns for this year (e.g. if some drug classes were not present in that year)
    cols_this_year <- cols_this_year[ cols_this_year %in% names(df) ]

    new_col <- paste0("desc_dat_stop_any_", gap, "_", yr)

    #select the minimum date across all drug classes for this year
    df <- df %>%
      mutate(
        !!new_col := do.call(
          pmin,
          c(across(all_of(cols_this_year)), na.rm = TRUE)
        )
      ) %>%
      mutate(
        !!new_col := if_else(
          is.infinite(.data[[new_col]]),
          as.Date(NA),
          as.Date(.data[[new_col]])
        )
      )
  }

  # Reshape data
  df_long <- df %>%
    pivot_longer(
      cols = matches(paste0("^(desc_dat_stop_any_", gap, "|inex_bin_all)_\\d{4}$")),
      names_to = c(".value", "year"),
      names_pattern = "(.*)_(\\d{4})"
    ) %>%
    mutate(
      year = as.numeric(year),
      event_date = as.Date(.data[[paste0("desc_dat_stop_any_", gap)]]),
      start_date = as.Date(paste0(year, "-01-01")),
      end_date = as.Date(paste0(year, "-12-31"))
    ) %>%
    filter(inex_bin_all) %>%
    mutate(
      event = if_else(!is.na(event_date) & event_date <= end_date, 1, 0),
      time = if_else(
        event == 1,
        as.numeric(event_date - start_date),
        as.numeric(end_date - start_date)
      )
    )

  # Survival model (using survfit to create cumulative incidence curves)

  surv_fit <- survfit(Surv(time, event) ~ factor(year), data = df_long)

  surv_df <- tidy(surv_fit) %>%
    mutate(
      year = as.numeric(str_remove(strata, "factor\\(year\\)=")),
      cum_inc = 1 - estimate
    )

  # Aggregate by week

  weekly_table <- surv_df %>%
    mutate(week = floor(time / 7) + 1) %>%
    group_by(year, week) %>%
    summarise(
      n_events = sum(n.event, na.rm = TRUE),
      cum_inc = max(cum_inc),
      .groups = "drop"
    ) %>%
    arrange(year, week) %>%
    group_by(year) %>%
    mutate(
      cum_events = cumsum(n_events),
      date_ref = as.Date("2000-01-01") + (week - 1) * 7
    ) %>%
    ungroup()

  # Midpoint6 rounding

  denom_table <- df_long %>%
    group_by(year) %>%
    summarise(
      n_eligible = roundmid_any(n()),
      .groups = "drop"
    )

  weekly_table_mid <- weekly_table %>%
    left_join(denom_table, by = "year") %>%
    mutate(
      cum_events_midpoint6 = roundmid_any(cum_events),
      cum_inc_midpoint6 = cum_events_midpoint6 / n_eligible
    )

  # Plot (this is just for viewing in backend.
  # We will output tables and then create plots based on these tables in post-processing)
  plot_obj <- ggplot(
    weekly_table,
    aes(date_ref, cum_inc, colour = factor(year))
  ) +
    geom_step(linewidth = 1) +
    scale_y_continuous(labels = scales::percent) +
    scale_x_date(
      date_labels = "%b",
      date_breaks = "1 month",
      limits = as.Date(c("2000-01-01", "2000-12-31"))
    ) +
    labs(
      title = paste0("Cumulative incidence (", gap, "-day gap)"),
      x = "Calendar time",
      y = "Patients stopping any drug (%)",
      colour = "Year"
    ) +
    theme_minimal() +
    theme(
      legend.position = "right",
      plot.title = element_text(hjust = 0.5, face = "bold")
    )

  # Plot (midpoint6)
  plot_mid <- ggplot(
    weekly_table_mid,
    aes(date_ref, cum_inc_midpoint6, colour = factor(year))
  ) +
    geom_step(linewidth = 1) +
    scale_y_continuous(labels = scales::percent) +
    scale_x_date(
      date_labels = "%b",
      date_breaks = "1 month",
      limits = as.Date(c("2000-01-01", "2000-12-31"))
    ) +
    labs(
      title = paste0("Cumulative incidence (", gap, "-day gap, midpoint6)"),
      x = "Calendar time",
      y = "Patients stopping any drug (%)",
      colour = "Year"
    ) +
    theme_minimal() +
    theme(
      legend.position = "right",
      plot.title = element_text(hjust = 0.5, face = "bold")
    )

  # ----------------------------------------------------------------------------
  # Save outputs
  # ----------------------------------------------------------------------------

  dir.create(here("output", "plots"), recursive = TRUE, showWarnings = FALSE)
  dir.create(here("output", "tables"), recursive = TRUE, showWarnings = FALSE)

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
    weekly_table_mid %>%
      select(year, week, cum_events_midpoint6, cum_inc_midpoint6),
    here("output", "tables", paste0("stop_any_", gap, "_cum_inc_midpoint6.csv"))
  )
}