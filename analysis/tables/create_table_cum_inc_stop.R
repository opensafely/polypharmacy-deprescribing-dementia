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

# ------------------------------------------------------------------------------
# Create "any stopping" variables
# ------------------------------------------------------------------------------

print("Create desc_dat_stop_any_YYYY variables")

# All drug classes
drug_classes <- c("acei", "bb", "arb", "aab", "ccb", "cca", "psd")

# Get all stop columns
stop_cols <- names(df) %>%
  str_subset("^desc_dat_stop_")

# Extract years
years <- stop_cols %>%
  str_extract("\\d{4}") %>%
  unique()

# Loop over years and create new variable
for (yr in years) {
  
  cols_this_year <- paste0("desc_dat_stop_", drug_classes, "_", yr)
  
  # Keep only columns that actually exist (defensive)
  cols_this_year <- cols_this_year[cols_this_year %in% names(df)]
  
  new_col <- paste0("desc_dat_stop_any_", yr)
  
  df <- df %>%
    mutate(
      !!new_col := do.call(
        pmin,
        c(across(all_of(cols_this_year)), na.rm = TRUE)
      )
    ) %>%
    mutate(
      # Fix Inf (happens when all are NA)
      !!new_col := if_else(
        is.infinite(.data[[new_col]]),
        as.Date(NA),
        as.Date(.data[[new_col]])
      )
    )
}

# ------------------------------------------------------------------------------
# Reshape data into long format
# ------------------------------------------------------------------------------

print("Reshape data")

df <- df %>%
  pivot_longer(
    cols = matches("^(desc_dat_stop_any|inex_bin_all)_\\d{4}$"),
    names_to = c(".value", "year"),
    names_pattern = "(.*)_(\\d{4})"
  ) %>%
  mutate(
    year = as.numeric(year),
    event_date = as.Date(desc_dat_stop_any),
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

# ------------------------------------------------------------------------------
# Survival model
# ------------------------------------------------------------------------------

print("Fit survfit")

surv_fit <- survfit(Surv(time, event) ~ factor(year), data = df)

surv_df <- tidy(surv_fit) %>%
  mutate(
    year = as.numeric(str_remove(strata, "factor\\(year\\)=")),
    cum_inc = 1 - estimate
  )

# ------------------------------------------------------------------------------
# Weekly aggregation
# ------------------------------------------------------------------------------

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

# ------------------------------------------------------------------------------
# Plot
# ------------------------------------------------------------------------------

print("Create cumulative incidence plot")

plot_stop_any <- ggplot(weekly_table, aes(date_ref, cum_inc, colour = factor(year))) +
  geom_step(linewidth = 1) +
  scale_y_continuous(labels = scales::percent) +
  scale_x_date(
    date_labels = "%b",
    date_breaks = "1 month",
    limits = as.Date(c("2000-01-01", "2000-12-31"))
  ) +
  labs(
    title = "Cumulative incidence of any antihypertensive stopping by year",
    x = "Calendar time",
    y = "Patients stopping any drug (%)",
    colour = "Year"
  ) +
  theme_minimal() +
  theme(
    legend.position = "right",
    plot.title = element_text(hjust = 0.5, face = "bold")
  )

# ------------------------------------------------------------------------------
# Save outputs
# ------------------------------------------------------------------------------

print("Save outputs")

dir.create(here("output", "plots"), recursive = TRUE, showWarnings = FALSE)
dir.create(here("output", "tables"), recursive = TRUE, showWarnings = FALSE)

ggsave(
  here("output", "plots", "stop_any_cum_inc.png"),
  plot_stop_any,
  width = 10,
  height = 6
)

write_csv(
  weekly_table %>% select(-date_ref),
  here("output", "tables", "stop_any_cum_inc.csv")
)
