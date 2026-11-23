# Load libraries ---------------------------------------------------------------
library(tidyverse)
library(survival)
library(broom)
library(scales)
library(here)

# Source common functions ------------------------------------------------------
print("Source common functions")
source("analysis/utility.R")
source("analysis/tables/fn-cum_inc_functions.R")

# Load data --------------------------------------------------------------------
print("Load cleaned dataset")
# One row per patient per year, for patients eligible on 1 January of that year
df <- read_rds(here("output", "dataset_clean", "input_clean_out.rds"))

# Event and follow-up time for each patient-year
# ------------------------------------------------------------------------------
print("Derive event and follow-up time")
df <- df %>%
  mutate(
    year = as.numeric(year),
    event_date = as.Date(out_dat_med_rev),
    start_date = as.Date(paste0(year, "-01-01")),
    end_date = as.Date(paste0(year, "-12-31"))
  ) %>%
  mutate(
    event = if_else(!is.na(event_date) & event_date <= end_date, 1, 0),
    time = if_else(event == 1,
                   as.numeric(event_date - start_date),
                   as.numeric(end_date - start_date))
  )

# Table of cumulative incidence summarised weekly ------------------------------
print("Fit survfit and aggregate data to weekly")
weekly_table <- cum_inc_weekly(df)

# Created redacted / midpoint rounded version
print("Creating redacted / midpoint rounded version")
weekly_table_mid <- cum_inc_weekly_midpoint6(weekly_table)

# Plots ------------------------------------------------------------------------
print("create cumulative incidence plots")
plot_med_reviews <- plot_cum_inc(
  weekly_table, "cum_inc",
  title = "Cumulative incidence of medication reviews by year",
  y_label = "Patients with medication review (%)"
)

plot_med_reviews_mid <- plot_cum_inc(
  weekly_table_mid, "cum_inc_midpoint6",
  title = "Cumulative incidence of medication reviews by year (rounded)",
  y_label = "Patients with medication review (%)"
)

# Save plots and tables --------------------------------------------------------
print("save plots and tables")
dir.create(here("output", "plots"), recursive = TRUE, showWarnings = FALSE)
dir.create(here("output", "tables"), recursive = TRUE, showWarnings = FALSE)

ggsave(
  here("output", "plots", "med_rev_cum_inc.png"),
  plot_med_reviews,
  width = 10,
  height = 6
)

write_csv(
  weekly_table %>% select(-date_ref),
  here("output", "tables", "med_rev_cum_inc.csv")
)

ggsave(
  here("output", "plots", "med_rev_cum_inc_midpoint6.png"),
  plot_med_reviews_mid,
  width = 10,
  height = 6
)

write_csv(
  weekly_table_mid %>% select(-date_ref),
  here("output", "tables", "med_rev_cum_inc_midpoint6.csv")
)
