modify_dummy <- function(df) {

  # Set seed -------------------------------------------------------------------
  set.seed(1)

  df <- df %>%

    mutate(
      patient_id = ifelse(
        row_number() %in% sample(n(), size = ceiling(0.002 * n())),
        NA_character_,  
        patient_id
      )
    ) %>%

    mutate(
      inex_bin_alive         = rbinom(n(), 1, 0.99) == 1,
      inex_bin_6m_reg        = rbinom(n(), 1, 0.99) == 1,
      inex_bin_antihyp = rbinom(n(), 1, 0.75) == 1,
      cov_bin_carehome = rbinom(n(), 1, 0.2) == 1,
    ) %>%

    ## Ethnicity
    mutate(
      cov_cat_ethnicity = sample(
        x = c("NA", "1", "2", "3", "4", "5"),
        size = nrow(.),
        replace = TRUE,
        prob = c(0.25, 0.15, 0.15, 0.15, 0.15, 0.15) # %15% for each category
      ),
    ) %>%

    ## Sex
    mutate(
      cov_cat_sex = sample(
        x = c("female", "male", "intersex", "unknown"),
        size = nrow(.),
        replace = TRUE,
        prob = c(0.49, 0.49, 0.01, 0.01) # %49% Female, 49% Male, 1% Intersex, 1% missing
      ),
      inex_bin_known_sex = cov_cat_sex != "unknown"
    ) %>%

    ## Age distribution (deliberately skewed towards older ages)
    mutate(
      cov_num_age = sample(
        c(
          sample(1:17, round(nrow(.) * 0.01), replace = TRUE), # Proportion <18
          sample(111:120, round(nrow(.) * 0.01), replace = TRUE), # Proportion >110
          sample(18:64, round(n() * 0.10), replace = TRUE),     # 10% under 65
          sample(65:110, n() - round(n() * 0.12), replace = TRUE) # 88% over 65
        )
      )
    ) %>%

    mutate(
      cov_num_age = ifelse(
        row_number() %in% sample(n(), size = ceiling(0.01 * n())),
        "-30",  # or "" if you prefer blank string
        cov_num_age
      )
    ) %>%

    ## Define over-64 indicator consistently
    mutate(inex_bin_over_64 = as.numeric(cov_num_age) >= 65) %>%

    ## Recalculate birth year based on new age
    mutate(
      qa_num_birth_year = as.numeric(format(as.Date(start_date), "%Y")) -
        as.numeric(cov_num_age)
    ) %>%

    ## Region
    mutate(
      cov_cat_region = sample(
        x = c(
          "East",
          "East Midlands",
          "London",
          "North East",
          "North West",
          "South East",
          "South West",
          "West Midlands",
          "Yorkshire and The Humber",
          ""
        ),
        size = nrow(.),
        replace = TRUE,
        prob = c(rep(0.11, 9), 0.01) # 11% for each area, %1 Missing
      ),
      inex_bin_known_region = cov_cat_region != ""
    ) %>%

    ## IMD
    mutate(
      cov_cat_imd = sample(
        x = c("1 (most deprived)", "2", "3", "4", "5 (least deprived)", NA),
        size = nrow(.),
        replace = TRUE,
        prob = c(rep(0.195, 5), 0.025) # 19.5% for each area, 2.5% missing
      ),
      inex_bin_known_imd = !is.na(cov_cat_imd)
    ) %>%

    ## Add CHD dates
    mutate(
      cov_dat_chd = as.Date(ifelse(
        runif(n()) < 0.4,  # ~40% chance
        sample(
          x = seq(as.Date("1970-01-01"), as.Date("2015-01-01"), by = "day"),
          size = n(),
          replace = TRUE
        ),
        NA
      ), origin = "1970-01-01")

    ) %>%

    ## Adding medication review date
    mutate(
      exp_date_med_rev = as.Date(ifelse(
        runif(n()) < 0.4,  # ~40% chance
        sample(
          x = seq(as.Date("2015-01-01"), as.Date("2020-01-01"), by = "day"),
          size = n(),
          replace = TRUE
        ),
        NA
      ), origin = "1970-01-01")

    ) %>%

    ## Adding dementia diagnosis dates
    mutate(
      cov_dat_dem = as.Date(ifelse(
        runif(n()) < 0.9,  # ~90% chance (not actually representative of UK)
        sample(
          x = seq(as.Date("1950-01-01"), as.Date("2020-01-01"), by = "day"),
          size = n(),
          replace = TRUE
        ),
        NA
      ), origin = "1970-01-01"),

      inex_bin_has_dem = !is.na(cov_dat_dem)
    ) %>%

    ## Dementia subtype indicators --------------------------------------------
    rowwise() %>%
    mutate(
      cov_bin_dem_alz = if (inex_bin_has_dem)
        rbinom(1, 1, 0.7) == 1 else FALSE,
      cov_bin_dem_vasc = if (inex_bin_has_dem)
        rbinom(1, 1, 0.4) == 1 else FALSE,
      cov_bin_dem_other = if (inex_bin_has_dem)
        rbinom(1, 1, 0.05) == 1 else FALSE
    ) %>%
    mutate(
      # Ensure at least one subtype TRUE if dementia present
      cov_bin_dem_other = ifelse(
        inex_bin_has_dem &
          !(
            cov_bin_dem_alz |
              cov_bin_dem_vasc |
              cov_bin_dem_other
          ),
        TRUE,
        cov_bin_dem_other
      )
    ) %>%
    ungroup() 

  return(df)

}