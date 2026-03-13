# Load libraries ---------------------------------------------------------------
library(tidyverse)
library(survival)
library(survminer)
library(broom)
library(scales)
library(here)
library(dplyr)
library(readr)
# Source common functions ------------------------------------------------------
print("Source common functions")
source("analysis/utility.R")
# Load data --------------------------------------------------------------------
print("Load cleaned dataset")
df <- read_rds(here("output", "dataset_clean", "input_clean_desc.rds"))

# Reshape data into long format for cumulative incidence stuff
# ------------------------------------------------------------------------------
print("Reshape data")
df <- df %>%
  pivot_longer(
    cols = matches("^(desc_dat_med_rev|inex_bin_all)_\\d{4}$"),
    names_to = c(".value", "year"),
    names_pattern = "(.*)_(\\d{4})"
  ) %>%
  # separate by year
  mutate(
    year = as.numeric(year),
    event_date = as.Date(desc_dat_med_rev),
    start_date = as.Date(paste0(year, "-01-01")),
    end_date = as.Date(paste0(year, "-12-31"))
  ) %>%
  filter(inex_bin_all) %>%
  mutate(
    event = if_else(!is.na(event_date) & event_date <= end_date, 1, 0),
    time = if_else(event == 1,
                   as.numeric(event_date - start_date),
                   as.numeric(end_date - start_date))
  )

# Use survfit ------------------------------------------------------------------
print("Fit survfit")
surv_fit <- survfit(Surv(time, event) ~ factor(year), data = df)

# Tidy survival output ---------------------------------------------------------
surv_df <- tidy(surv_fit) %>%
  mutate(
    year = as.numeric(str_remove(strata, "factor\\(year\\)=")),
    cum_inc = 1 - estimate
  )


# Table of cumulative incidence summarised weekyl
print("Aggregate data to weekly")
weekly_table <- surv_df %>%
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
  ungroup()


# Plot -------------------------------------------------------------------------
# Note: plots are created as "supporting info" in this instance. We will use the 
# tables to create plots as needed in post
print("create cumulative incidence plot")

plot_med_reviews <- ggplot(weekly_table, aes(date_ref, cum_inc, colour = factor(year))) +
  geom_step(linewidth = 1) +
  scale_y_continuous(labels = scales::percent) +
  scale_x_date(
    date_labels = "%b",
    date_breaks = "1 month",
    limits = as.Date(c("2000-01-01", "2000-12-31"))
  ) +
  labs(
    title = "Cumulative incidence of medication reviews by year",
    x = "Calendar time",
    y = "Patients with medication review (%)",
    colour = "Year"
  ) +
  theme_minimal() +
  theme(
    legend.position = "right",
    plot.title = element_text(hjust = 0.5, face = "bold")
  )

# Save plot --------------------------------------------------------------------
print("save plots and table")
dir.create(here("output", "plots"), recursive = TRUE, showWarnings = FALSE)
dir.create(here("output", "tables"), recursive = TRUE, showWarnings = FALSE)

ggsave(
  here("output", "plots", "med_rev_cum_inc.png"),
  plot_med_reviews,
  width = 10,
  height = 6
)

# Save table
write_csv(
  weekly_table %>% select(-date_ref),
  here("output", "tables", "med_rev_cum_inc.csv")
)

#------------------------------------------------
# Created redacted / midpoint rounded version
#------------------------------------------------
print("Creating redacted / midpoint rounded version")

# Get denominator (eligible patients per year)
denom_table <- df %>%
  group_by(year) %>%
  summarise(
    n_eligible = roundmid_any(n()),
    .groups = "drop"
  )

weekly_table <- weekly_table %>%
  left_join(denom_table, by = "year")

# Calculated rounded values
weekly_table <- weekly_table %>%
  mutate(
    cum_events_midpoint6 = roundmid_any(cum_events)
  ) %>%
  group_by(year) %>%
  arrange(week, .by_group = TRUE) %>%
  mutate(
    cum_inc_midpoint6 = cum_events_midpoint6 / n_eligible
  ) %>%
  ungroup() %>%
  select(year, week, date_ref, cum_events_midpoint6, cum_inc_midpoint6)

# Plot -------------------------------------------------------------------------
print("save rounded plot")
print("save rounded plot")

plot_med_reviews <- ggplot(weekly_table, aes(date_ref, cum_inc_midpoint6, colour = factor(year))) +
  geom_step(linewidth = 1) +
  scale_y_continuous(labels = percent) +
  scale_x_date(
    date_labels = "%b",
    date_breaks = "1 month",
    limits = as.Date(c("2000-01-01", "2000-12-31"))
  ) +
  labs(
    title = "Cumulative incidence of medication reviews by year (rounded)",
    x = "Calendar time",
    y = "Patients with medication review (%)",
    colour = "Year"
  ) +
  theme_minimal() +
  theme(
    legend.position = "right",
    plot.title = element_text(hjust = 0.5, face = "bold")
  )

print("save table and plot")
# Save table
write_csv(
  weekly_table %>% select(-date_ref),
  here("output", "tables", "med_rev_cum_inc_midpoint6.csv")
)

# Save plot
ggsave(
  here("output", "plots", "med_rev_cum_inc_midpoint6.png"),
  plot_med_reviews,
  width = 10,
  height = 6
)
