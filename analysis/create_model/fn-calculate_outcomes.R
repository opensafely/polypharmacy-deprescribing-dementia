calculate_outcomes <- function(input, gap){

  # identify all "next" date columns
  next_cols <- grep("^out_dat_next_", names(input), value = TRUE)

  # extract medication class names
  med_classes <- sub("^out_dat_next_", "", next_cols)

  # loop over medication classes
  for (cls in med_classes) {

    prev_col <- paste0("out_dat_prev_", cls)
    next_col <- paste0("out_dat_next_", cls)
    out_col  <- paste0("out_bin_stopped_", cls)

    # compute gap and stopping indicator
    input <- input %>%
      mutate(
        !!paste0("gap_days_", cls) := as.numeric(.data[[next_col]] - .data[[prev_col]]),

        !!out_col := case_when(
          is.na(.data[[next_col]]) ~ 1,
          .data[[paste0("gap_days_", cls)]] > gap ~ 1,
          TRUE ~ 0
        )
      )
  }


  input
}