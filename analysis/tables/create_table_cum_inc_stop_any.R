# Load libraries

library(tidyverse)
library(survival)
library(broom)
library(here)

# Source common functions

print("Source common functions")
source("analysis/utility.R")

# Load data

print("Load cleaned dataset")
# Stopping dates and censoring dates (death, deregistration) both come from the out dataset.
# One row per patient per year, for patients eligible on 1 January of that year.
df <- read_rds(here("output", "dataset_clean", "input_clean_out.rds"))

# Define drug classes and gap sizes for stopping definitions

drug_classes <- c("acei", "bb", "arb", "aab", "ccb", "caa", "psd", "ttd")
gap_sizes <- c("90", "120", "180")

# ------------------------------------------------------------------------------
# Main loop over gap sizes

for (gap in gap_sizes) {

  print(paste("Processing gap:", gap))

  # "Stop any": the earliest stop across all drug classes for this gap size
  stop_cols <- paste0("out_dat_stop_", drug_classes, "_", gap)
  stop_cols <- stop_cols[stop_cols %in% names(df)]

  df_long <- df %>%
    mutate(
      event_date = do.call(pmin, c(across(all_of(stop_cols)), na.rm = TRUE)),
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

  # Survival model (using survfit to create cumulative incidence curves)

  surv_fit <- survfit(Surv(time, event) ~ factor(year), data = df_long)

  surv_df <- tidy(surv_fit) %>%
    mutate(
      year = as.numeric(str_remove(strata, "factor\\(year\\)=")),
      cum_inc = 1 - estimate
    )

  # Aggregate by week
  
  denom_table <- df_long %>%
    group_by(year) %>%
    summarise(
      denominator = n(),
      denominator_midpoint6 = roundmid_any(n()),
      .groups = "drop"
    )

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
    ungroup() %>%
    left_join(denom_table, by = "year")

  # Midpoint6 rounding

  weekly_table_mid <- weekly_table %>%
    mutate(
      cum_events_midpoint6 = roundmid_any(cum_events),
      cum_inc_midpoint6 = cum_events_midpoint6 / denominator_midpoint6
    ) %>%
    select(
      year,
      week,
      date_ref,
      cum_events_midpoint6,
      cum_inc_midpoint6,
      denominator_midpoint6
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
    weekly_table %>% select(-date_ref,-denominator_midpoint6),
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
      select(year, week, cum_events_midpoint6, cum_inc_midpoint6, denominator_midpoint6),
    here("output", "tables", paste0("stop_any_", gap, "_cum_inc_midpoint6.csv"))
  )
}