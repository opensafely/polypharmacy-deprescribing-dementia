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

# Output dirs ------------------------------------------------------------------
dir.create(here("output", "plots"), recursive = TRUE, showWarnings = FALSE)
dir.create(here("output", "tables"), recursive = TRUE, showWarnings = FALSE)

# ------------------------------------------------------------------------------
# Function to run cumulative incidence for a given drug class
# ------------------------------------------------------------------------------

run_cuminc_for_class <- function(df, drug_class) {
  
  print(paste("Running for:", drug_class))
  
  # --------------------------------------------------------------------------
  # Reshape
  # --------------------------------------------------------------------------
  
  pattern <- paste0("^(desc_dat_stop_", drug_class, "|inex_bin_all)_\\d{4}$")
  
  df_long <- df %>%
    pivot_longer(
      cols = matches(pattern),
      names_to = c(".value", "year"),
      names_pattern = "(.*)_(\\d{4})"
    ) %>%
    mutate(
      year = as.numeric(year),
      event_date = as.Date(.data[[paste0("desc_dat_stop_", drug_class)]]),
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
  
  # --------------------------------------------------------------------------
  # Survival
  # --------------------------------------------------------------------------
  
  surv_fit <- survfit(Surv(time, event) ~ factor(year), data = df_long)
  
  surv_df <- tidy(surv_fit) %>%
    mutate(
      year = as.numeric(str_remove(strata, "factor\\(year\\)=")),
      cum_inc = 1 - estimate
    )
  
  # --------------------------------------------------------------------------
  # Weekly aggregation
  # --------------------------------------------------------------------------
  
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
  
  # --------------------------------------------------------------------------
  # Plot
  # --------------------------------------------------------------------------
  
  plot_obj <- ggplot(weekly_table, aes(date_ref, cum_inc, colour = factor(year))) +
    geom_step(linewidth = 1) +
    scale_y_continuous(labels = scales::percent) +
    scale_x_date(
      date_labels = "%b",
      date_breaks = "1 month",
      limits = as.Date(c("2000-01-01", "2000-12-31"))
    ) +
    labs(
      title = paste("Cumulative incidence of", toupper(drug_class), "stopping by year"),
      x = "Calendar time",
      y = paste("Patients stopping", toupper(drug_class), "(%)"),
      colour = "Year"
    ) +
    theme_minimal() +
    theme(
      legend.position = "right",
      plot.title = element_text(hjust = 0.5, face = "bold")
    )
  
  # --------------------------------------------------------------------------
  # Save outputs
  # --------------------------------------------------------------------------
  
  ggsave(
    here("output", "plots", paste0("stop_", drug_class, "_cum_inc.png")),
    plot_obj,
    width = 10,
    height = 6
  )
  
  write_csv(
    weekly_table %>% select(-date_ref),
    here("output", "tables", paste0("stop_", drug_class, "_cum_inc.csv"))
  )
  
  return(invisible(NULL))
}

# ------------------------------------------------------------------------------
# Run for all drug classes
# ------------------------------------------------------------------------------

drug_classes <- c("acei", "bb", "arb", "aab", "ccb", "cca", "psd")

walk(drug_classes, ~ run_cuminc_for_class(df, .x))