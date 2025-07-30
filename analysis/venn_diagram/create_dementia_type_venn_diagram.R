library(readr)
library(here)
library(dplyr)
library(stringr)
library(fs)
library(purrr)
library(ggvenn)


# Step 1 :Load data
df_dataset <- read_csv(
  here("output", "dataset.csv.gz"),
  col_types = cols(
    latest_dementia_code = col_character(),
    latest_alzheimers_code = col_character(),
    latest_vascular_dementia_code = col_character(),
    latest_other_dementia_code = col_character()
  )
)

df_dataset <- df_dataset %>%
  mutate(
    has_alz = str_trim(latest_alzheimers_code) != "",
    has_vasc = str_trim(latest_vascular_dementia_code) != "",
    has_other = str_trim(latest_other_dementia_code) != ""
  )

# Step 2: Create sets of patient IDs
alz_patients <- df_dataset %>% filter(has_alz) %>% pull(patient_id)
vasc_patients <- df_dataset %>% filter(has_vasc) %>% pull(patient_id)
other_patients <- df_dataset %>% filter(has_other) %>% pull(patient_id)

venn_data <- list(
  "Alzheimer's" = unique(alz_patients),
  "Vascular" = unique(vasc_patients),
  "Other" = unique(other_patients)
)

# Create plot
venn_plot <- ggvenn(
  venn_data,
  fill_color = c("skyblue", "seagreen", "orange"),
  stroke_size = 0.8,
  set_name_size = 6,
  text_size = 5
)

# Save to output/plots/venn
output_dir <- here("output", "plots")
fs::dir_create(output_dir)

ggsave(
  filename = file.path(output_dir, "dementia_venn.png"),
  plot = venn_plot,
  width = 7,
  height = 7,
  dpi = 300
)