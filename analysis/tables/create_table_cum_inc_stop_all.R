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

# Load cleaned dataset ---------------------------------------------------------

print("Load cleaned dataset")

df <- read_rds(
  here("output", "dataset_clean", "input_clean_desc.rds")
)

# Create output directories ----------------------------------------------------

dir.create(
  here("output", "plots"),
  recursive = TRUE,
  showWarnings = FALSE
)

dir.create(
  here("output", "tables"),
  recursive = TRUE,
  showWarnings = FALSE
)

# ------------------------------------------------------------------------------
# Define antihypertensive drug classes
# ------------------------------------------------------------------------------

drug_classes <- c(
  "acei",
  "bb",
  "arb",
  "aab",
  "ccb",
  "caa",
  "psd"
)

# ------------------------------------------------------------------------------
# Define stopping gap sizes
# ------------------------------------------------------------------------------

gap_sizes <- c("30", "90", "180")

# ------------------------------------------------------------------------------
# Create "any stopping" variables
# ------------------------------------------------------------------------------

# These contain the earliest stopping date across all antihypertensive
# drug classes within each calendar year and gap definition.

print("Create desc_dat_stop_any variables")

# Get all stopping columns
stop_cols <- names(df) %>%
  str_subset("^desc_dat_stop_")

# Extract all years from stopping variables
years <- stop_cols %>%
  str_extract("\\d{4}") %>%
  unique()

# Loop through gap sizes and years
for (gap in gap_sizes) {

  for (yr in years) {

    cols_this_year <- paste0(
      "desc_dat_stop_",
      drug_classes,
      "_",
      gap,
      "_",
      yr
    )

    # Keep only columns that exist
    cols_this_year <- cols_this_year[
      cols_this_year %in% names(df)
    ]

    new_col <- paste0(
      "desc_dat_stop_any_",
      gap,
      "_",
      yr
    )

    df <- df %>%
      mutate(
        !!new_col := do.call(
          pmin,
          c(
            across(all_of(cols_this_year)),
            na.rm = TRUE
          )
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
}

# ------------------------------------------------------------------------------
# Function to run cumulative incidence analysis
# ------------------------------------------------------------------------------

run_cuminc <- function(
    df,
    event_prefix,
    output_name,
    plot_title,
    y_label
) {

  print(
    paste(
      "Running cumulative incidence for:",
      output_name
    )
  )

  # --------------------------------------------------------------------------
  # Reshape into long format
  # --------------------------------------------------------------------------

  pattern <- paste0(
    "^(",
    event_prefix,
    "|inex_bin_all)_\\d{4}$"
  )

  df_long <- df %>%
    pivot_longer(
      cols = matches(pattern),
      names_to = c(".value", "year"),
      names_pattern = "(.*)_(\\d{4})"
    ) %>%
    mutate(
      year = as.numeric(year),
      event_date = as.Date(.data[[event_prefix]]),
      start_date = as.Date(
        paste0(year, "-01-01")
      ),
      end_date = as.Date(
        paste0(year, "-12-31")
      )
    ) %>%
    filter(inex_bin_all) %>%
    mutate(
      event = if_else(
        !is.na(event_date) &
          event_date <= end_date,
        1,
        0
      ),
      time = if_else(
        event == 1,
        as.numeric(event_date - start_date),
        as.numeric(end_date - start_date)
      )
    )

  # --------------------------------------------------------------------------
  # Fit survival model
  # --------------------------------------------------------------------------

  surv_fit <- survfit(
    Surv(time, event) ~ factor(year),
    data = df_long
  )

  # Convert survival output into cumulative incidence
  surv_df <- tidy(surv_fit) %>%
    mutate(
      year = as.numeric(
        str_remove(
          strata,
          "factor\\(year\\)="
        )
      ),
      cum_inc = 1 - estimate
    )

  # --------------------------------------------------------------------------
  # Aggregate to weekly cumulative incidence
  # --------------------------------------------------------------------------

  weekly_table <- surv_df %>%
    mutate(
      week = floor(time / 7) + 1
    ) %>%
    group_by(year, week) %>%
    summarise(
      n_events = sum(
        n.event,
        na.rm = TRUE
      ),
      cum_inc = max(cum_inc),
      .groups = "drop"
    ) %>%
    arrange(year, week) %>%
    group_by(year) %>%
    mutate(
      cum_events = cumsum(n_events),
      date_ref = as.Date("2000-01-01") +
        (week - 1) * 7
    ) %>%
    ungroup()

  # --------------------------------------------------------------------------
  # Create cumulative incidence plot
  # --------------------------------------------------------------------------

  plot_obj <- ggplot(
    weekly_table,
    aes(
      date_ref,
      cum_inc,
      colour = factor(year)
    )
  ) +
    geom_step(linewidth = 1) +
    scale_y_continuous(
      labels = scales::percent
    ) +
    scale_x_date(
      date_labels = "%b",
      date_breaks = "1 month",
      limits = as.Date(
        c("2000-01-01", "2000-12-31")
      )
    ) +
    labs(
      title = plot_title,
      x = "Calendar time",
      y = y_label,
      colour = "Year"
    ) +
    theme_minimal() +
    theme(
      legend.position = "right",
      plot.title = element_text(
        hjust = 0.5,
        face = "bold"
      )
    )

  # --------------------------------------------------------------------------
  # Save standard outputs
  # --------------------------------------------------------------------------

  print(
    paste(
      "Saving outputs for:",
      output_name
    )
  )

  ggsave(
    here(
      "output",
      "plots",
      paste0(
        output_name,
        "_cum_inc.png"
      )
    ),
    plot_obj,
    width = 10,
    height = 6
  )

  write_csv(
    weekly_table %>%
      select(-date_ref),
    here(
      "output",
      "tables",
      paste0(
        output_name,
        "_cum_inc.csv"
      )
    )
  )

  # --------------------------------------------------------------------------
  # Create midpoint6 rounded outputs
  # --------------------------------------------------------------------------

  print(
    paste(
      "Creating midpoint6 outputs for:",
      output_name
    )
  )

  # Calculate denominator per year
  denom_table <- df_long %>%
    group_by(year) %>%
    summarise(
      n_eligible = roundmid_any(n()),
      .groups = "drop"
    )

  # Apply midpoint rounding to cumulative events
  weekly_table_mid <- weekly_table %>%
    left_join(
      denom_table,
      by = "year"
    ) %>%
    mutate(
      cum_events_midpoint6 = roundmid_any(
        cum_events
      )
    ) %>%
    group_by(year) %>%
    arrange(
      week,
      .by_group = TRUE
    ) %>%
    mutate(
      cum_inc_midpoint6 =
        cum_events_midpoint6 /
        n_eligible
    ) %>%
    ungroup()

  # --------------------------------------------------------------------------
  # Create midpoint6 plot
  # --------------------------------------------------------------------------

  plot_mid <- ggplot(
    weekly_table_mid,
    aes(
      date_ref,
      cum_inc_midpoint6,
      colour = factor(year)
    )
  ) +
    geom_step(linewidth = 1) +
    scale_y_continuous(
      labels = scales::percent
    ) +
    scale_x_date(
      date_labels = "%b",
      date_breaks = "1 month",
      limits = as.Date(
        c("2000-01-01", "2000-12-31")
      )
    ) +
    labs(
      title = paste0(
        plot_title,
        " (rounded)"
      ),
      x = "Calendar time",
      y = y_label,
      colour = "Year"
    ) +
    theme_minimal() +
    theme(
      legend.position = "right",
      plot.title = element_text(
        hjust = 0.5,
        face = "bold"
      )
    )

  # --------------------------------------------------------------------------
  # Save midpoint6 outputs
  # --------------------------------------------------------------------------

  ggsave(
    here(
      "output",
      "plots",
      paste0(
        output_name,
        "_cum_inc_midpoint6.png"
      )
    ),
    plot_mid,
    width = 10,
    height = 6
  )

  write_csv(
    weekly_table_mid %>%
      select(
        year,
        week,
        cum_events_midpoint6,
        cum_inc_midpoint6
      ),
    here(
      "output",
      "tables",
      paste0(
        output_name,
        "_cum_inc_midpoint6.csv"
      )
    )
  )

  return(invisible(NULL))
}

# ------------------------------------------------------------------------------
# Run cumulative incidence for each drug class and gap size
# ------------------------------------------------------------------------------

walk(
  gap_sizes,
  function(gap) {

    walk(
      drug_classes,
      function(drug) {

        run_cuminc(
          df = df,

          event_prefix = paste0(
            "desc_dat_stop_",
            drug,
            "_",
            gap
          ),

          output_name = paste0(
            "stop_",
            drug,
            "_",
            gap
          ),

          plot_title = paste(
            "Cumulative incidence of",
            toupper(drug),
            "stopping by year",
            "(",
            gap,
            "gap definition)"
          ),

          y_label = paste(
            "Patients stopping",
            toupper(drug),
            "(%)"
          )
        )

      }
    )

  }
)

# ------------------------------------------------------------------------------
# Run cumulative incidence for any antihypertensive stopping
# ------------------------------------------------------------------------------

walk(
  gap_sizes,
  function(gap) {

    run_cuminc(
      df = df,

      event_prefix = paste0(
        "desc_dat_stop_any_",
        gap
      ),

      output_name = paste0(
        "stop_any_",
        gap
      ),

      plot_title = paste(
        "Cumulative incidence of any antihypertensive stopping by year",
        "(",
        gap,
        "gap definition)"
      ),

      y_label = "Patients stopping any drug (%)"
    )

  }
)