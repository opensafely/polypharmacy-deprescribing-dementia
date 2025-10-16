modify_dummy <- function(df) {
  # Set seed -------------------------------------------------------------------
  set.seed(1)

  df <- df %>%

    mutate(
      inex_bin_alive         = rbinom(n(), 1, 0.99) == 1,
      inex_bin_6m_reg        = rbinom(n(), 1, 0.99) == 1,
      inex_bin_has_dem  = rbinom(n(), 1, 0.9) == 1,
      inex_bin_antihyp = rbinom(n(), 1, 0.75) == 1
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

    ## Adding medication review date
    mutate(
      exp_date_medication_review = ifelse(
        runif(n()) < 0.4,  # ~40% chance
        sample(
          x = seq(as.Date("2015-01-01"), as.Date("2020-01-01"), by = "day"),
          size = n(),
          replace = TRUE
        ),
        NA
      )
    ) %>%

    ## Adding dementia diagnosis dates
    mutate(
      cov_dat_dem_diag = ifelse(
        runif(n()) < 0.5,  # ~50% chance (not actually representative of UK)
        sample(
          x = seq(as.Date("1950-01-01"), as.Date("2020-01-01"), by = "day"),
          size = n(),
          replace = TRUE
        ),
        NA
      ),
      inex_bin_has_dem = !is.na(cov_dat_dem_diag)
    ) %>%

    ## Dementia subtype indicators --------------------------------------------
    rowwise() %>%
    mutate(
      cov_bin_alz_diag = if (inex_bin_has_dem)
        rbinom(1, 1, 0.7) == 1 else FALSE,
      cov_bin_vasc_diag = if (inex_bin_has_dem)
        rbinom(1, 1, 0.4) == 1 else FALSE,
      cov_bin_other_diag = if (inex_bin_has_dem)
        rbinom(1, 1, 0.05) == 1 else FALSE
    ) %>%
    mutate(
      # Ensure at least one subtype TRUE if dementia present
      cov_bin_other_diag = ifelse(
        inex_bin_has_dem &
          !(
            cov_bin_alz_diag |
              cov_bin_vasc_diag |
              cov_bin_other_diag
          ),
        TRUE,
        cov_bin_other_diag
      )
    ) %>%
    ungroup() %>%

    ## Convert date variables to Date type 
    mutate(
      exp_date_medication_review = as.Date(exp_date_medication_review, origin = "1970-01-01"),
      cov_dat_dem_diag = as.Date(cov_dat_dem_diag, origin = "1970-01-01")
    )

}