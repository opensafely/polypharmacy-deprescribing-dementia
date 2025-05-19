library(readr)
library(here)
library(dplyr)
library(stringr)
library(fs)

# Load data
df_dataset <- read_csv(here("output", "dataset.csv.gz"))

df_tab1 <- df_dataset %>%
  group_by(sex) %>%
  summarise(
    n = n(),
    age_min = min(age, na.rm = TRUE),
    age_max = max(age, na.rm = TRUE),
    age_mean = mean(age, na.rm = TRUE)
  ) %>%
  mutate(n = round(n, -1))

dir_create(here("output", "tables"))

write_csv(
  df_tab1,
  here("output", "tables", "table1.csv")
)
