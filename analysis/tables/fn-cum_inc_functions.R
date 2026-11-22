# Functions for the cumulative incidence tables and plots.
# Need tidyverse, survival and broom loaded, and roundmid_any() from analysis/utility.R.

# Weekly cumulative incidence for each year (raw counts only), from a data frame with
# one row per patient-year and the columns year, time (days from 1 January) and
# event (1 = event, 0 = censored)
cum_inc_weekly <- function(df) {

  # Kaplan-Meier fit for each year, cumulative incidence = 1 - survival
  surv_df <- tidy(survfit(Surv(time, event) ~ factor(year), data = df)) %>%
    mutate(
      year = as.numeric(str_remove(strata, "factor\\(year\\)=")),
      cum_inc = 1 - estimate
    )

  # Denominators (eligible patients per year)
  denom_table <- df %>%
    group_by(year) %>%
    summarise(
      denominator = n(),
      .groups = "drop"
    )

  # Summarise by week. date_ref puts every year on the same calendar axis for plotting
  surv_df %>%
    mutate(
      week = floor(time / 7) + 1
    ) %>%
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
}

# Midpoint6 rounded version of the weekly table from cum_inc_weekly()
cum_inc_weekly_midpoint6 <- function(weekly_table) {
  weekly_table %>%
    mutate(
      cum_events_midpoint6 = roundmid_any(cum_events),
      denominator_midpoint6 = roundmid_any(denominator),
      cum_inc_midpoint6 = cum_events_midpoint6 / denominator_midpoint6
    ) %>%
    select(year, week, date_ref, cum_events_midpoint6, cum_inc_midpoint6, denominator_midpoint6)
}

# Cumulative incidence plot by year. These plots are for viewing only; plots for
# reporting are made from the output tables in post-processing.
# y - the column to plot (cum_inc or cum_inc_midpoint6)
plot_cum_inc <- function(weekly_table, y, title, y_label) {
  ggplot(weekly_table, aes(date_ref, .data[[y]], colour = factor(year))) +
    geom_step(linewidth = 1) +
    scale_y_continuous(labels = scales::percent) +
    scale_x_date(
      date_labels = "%b",
      date_breaks = "1 month",
      limits = as.Date(c("2000-01-01", "2000-12-31"))
    ) +
    labs(
      title = title,
      x = "Calendar time",
      y = y_label,
      colour = "Year"
    ) +
    theme_minimal() +
    theme(
      legend.position = "right",
      plot.title = element_text(hjust = 0.5, face = "bold")
    )
}
