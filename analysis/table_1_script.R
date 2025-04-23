# Load necessary libraries
install.packages("readr")
install.packages("dplyr")

library(readr)
library(dplyr)

# Create output directory if it doesn't exist
if (!dir.exists("outputs")) dir.create("outputs")

# Load data
data <- read_csv("output/dataset.csv.gz")

# Clean missing values
data$ethnicity[is.na(data$ethnicity)] <- "Unknown"

# Convert categorical variables to factors
data <- data %>%
  mutate(
    sex = as.factor(sex),
    dementia_type = as.factor(latest_dementia_code),
    region = as.factor(region),
    ethnicity = as.factor(ethnicity)
  )

# Define variables
categorical_vars <- c("sex", "dementia_type", "region", "ethnicity")
continuous_vars <- c("age", "imd")

# Initialize a character vector to store output
table_output <- c()

# Summarize categorical variables
for (var in categorical_vars) {
  table_output <- c(table_output, paste0("== ", var, " =="))
  freq_table <- data %>%
    group_by(.data[[var]]) %>%
    summarise(n = n()) %>%
    mutate(percent = round(n / sum(n) * 100, 1))
  
  for (i in 1:nrow(freq_table)) {
    row <- freq_table[i, ]
    table_output <- c(table_output,
                      sprintf("  %s: %d (%.1f%%)",
                              as.character(row[[var]]),
                              row$n,
                              row$percent))
  }
  table_output <- c(table_output, "")
}

# Summarize continuous variables
for (var in continuous_vars) {
  summary_stats <- data %>%
    summarise(
      Mean = mean(.data[[var]], na.rm = TRUE),
      SD = sd(.data[[var]], na.rm = TRUE),
      Median = median(.data[[var]], na.rm = TRUE),
      IQR = IQR(.data[[var]], na.rm = TRUE)
    )
  table_output <- c(table_output,
                    paste0("== ", var, " =="),
                    sprintf("  Mean (SD): %.2f (%.2f)", summary_stats$Mean, summary_stats$SD),
                    sprintf("  Median (IQR): %.2f (%.2f)", summary_stats$Median, summary_stats$IQR),
                    "")
}

# Write to file
writeLines(table_output, "output/table_1.txt")
