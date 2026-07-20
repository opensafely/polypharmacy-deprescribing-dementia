
create_table1 <- function(df) {
  #Select variables of interest
  df_table1 <- df %>%
    select(
      patient_id,
      exp_bin_med_rev,
      cov_num_age,
      starts_with("cov_cat_"),
      starts_with("cov_bin_"),
      starts_with("strat_cat_")
    ) %>%
    mutate(
      across(-c(patient_id, exp_bin_med_rev, cov_num_age),as.character),
      All = "All")
  
  # Long format for counting
  df_long <- df_table1 %>%
    pivot_longer(
      cols = -c(patient_id, exp_bin_med_rev, cov_num_age),
      names_to = "characteristic",
      values_to = "subcharacteristic"
    )
  
  #Clean missing values
  df_long <- df_long %>%
    mutate(
      subcharacteristic = case_when(
        is.na(subcharacteristic)       ~ "Missing",
        subcharacteristic == ""        ~ "Missing",
        subcharacteristic == "unknown" ~ "Missing",
        TRUE                           ~ as.character(subcharacteristic)
      )
    )
  
  # Calculate median age (IQR)
  median_iqr_age <- paste0(
    round(median(df_table1$cov_num_age, na.rm = TRUE), 1),
    " (",
    round(quantile(df_table1$cov_num_age, 0.25, na.rm = TRUE), 1),
    "-",
    round(quantile(df_table1$cov_num_age, 0.75, na.rm = TRUE), 1),
    ")"
  )
  
  # Aggregate counts
  table1 <- df_long %>%
    group_by(characteristic, subcharacteristic) %>%
    summarise(N = n(),
              exposed_N = sum(exp_bin_med_rev, na.rm = TRUE),
              .groups = "drop"
    ) %>%
    mutate(N = as.character(N),
           exposed_N = as.character(exposed_N)
    ) %>%
    arrange(characteristic, subcharacteristic)
  
  # Calculate percentages
  total_count <- as.numeric(table1$N[table1$characteristic == "All"][1])
  
  table1 <- table1 %>%
    mutate(
      percent_of_total_population = if_else(
        characteristic == "All", "",
        paste0(
          round(100 * as.numeric(N) / total_count, 1), "%"
        )
      ),
      percent_exposed = if_else(
        as.numeric(N) > 0,
        paste0(
          round(100 * as.numeric(exposed_N) / as.numeric(N), 1), "%"
        ),
        ""
      )
    )
  
  # Append median age row
  table1 <- bind_rows(table1,
                      tibble(characteristic = "Age, years", subcharacteristic = "Median (IQR)", N = median_iqr_age)
  )
  return(table1)
}

# Function to create midpoint6 redacted Table 1
create_midpoint6_table1 <- function(table1) {
  
  # Keep age row separately
  age_rows <- table1 %>%
    filter(subcharacteristic == "Median (IQR)")
  
  # Apply midpoint6 rounding
  table1_redacted <- table1 %>%
    filter(subcharacteristic != "Median (IQR)") %>%
    mutate(
      N_midpoint6 = roundmid_any(as.numeric(N)),
      exposed_midpoint6 = roundmid_any(as.numeric(exposed_N))
    )
  
  # Calculate denominator after rounding
  total_N_midpoint6 <- table1_redacted %>%
    filter(characteristic == "All") %>%
    pull(N_midpoint6) %>%
    first()
  
  # Recalculate percentages
  table1_redacted <- table1_redacted %>%
    mutate(
      percent_midpoint6 = if_else(
        characteristic == "All",
        "",
        paste0(
          round(100 * N_midpoint6 / total_N_midpoint6, 1),
          "%"
        )
      ),
      percent_exposed_midpoint6 = if_else(
        N_midpoint6 > 0,
        paste0(
          round(100 * exposed_midpoint6 / N_midpoint6, 1),
          "%"
        ),
        ""
      )
    ) %>%
    select(
      characteristic,
      subcharacteristic,
      N_midpoint6,
      percent_midpoint6,
      exposed_midpoint6,
      percent_exposed_midpoint6
    ) %>%
    mutate(
      N_midpoint6 = as.character(N_midpoint6),
      exposed_midpoint6 = as.character(exposed_midpoint6)
    )
  
  # Re-append age row
  table1_redacted <- bind_rows(
    table1_redacted,
    age_rows %>%
      transmute(
        characteristic,
        subcharacteristic,
        N_midpoint6 = N,
        percent_midpoint6 = "",
        exposed_midpoint6 = "",
        percent_exposed_midpoint6 = ""
      )
  ) %>%
    arrange(characteristic, subcharacteristic)
  
  return(table1_redacted)
  
}
