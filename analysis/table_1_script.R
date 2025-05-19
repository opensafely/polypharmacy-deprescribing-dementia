library(readr)
library(dplyr)
library(stringr)

# Load data
data <- read_csv("output/dataset.csv.gz")
dementia_codes <- read_csv("codelists/nhsd-primary-care-domain-refsets-dem_cod.csv")
# Create dementia type mapping

dementia_classified <- dementia_codes %>%
  mutate(
    # Ensure 'term' is character, handle potential NAs gracefully
    term = as.character(term),
    term_lower = tolower(term), # Convert to lowercase for case-insensitive matching
    
    # Check for Alzheimer's first, then Vascular, then default to Other.
    dementia_type = case_when(
      # Alzheimer's disease: check for 'alzheimer'
      str_detect(term_lower, "alzheimer") ~ "alzheimer's disease",
      
      # Vascular dementia: check for relevant keywords
      str_detect(term_lower, "vascular|multi-infarct|multi infarct|atherosclerosis|cerebral vasculitis|hemorrhagic cerebral infarction") ~ "vascular dementia",
      
      # Default category if none of the above keywords are found
      TRUE ~ "other"
    ),
    
    # Remove the temporary lowercase column if no longer needed
    term_lower = NULL
  )

merged_data <- merge(data, dementia_classified, by.x = "latest_dementia_code", by.y = "code", all.x = TRUE)

# Calculate summary statistics
mean_age <- mean(mean(data$age))
sd_age <- sd(data$age)

sex_counts <- table(data$sex)
region_counts <- table(data$region)

total <- sum(sex_counts)

dementia_counts <- table(merged_data$dementia_type)

#Format output

line0 <- sprintf("total : %d", total)
line1 <- sprintf("age : %.2f +/- %.2f", mean_age, sd_age)

sex_parts <- sprintf("%s = %d (%.2f%%)",names(sex_counts),as.integer(sex_counts), 100 * sex_counts / total)
line2 <- paste("sex :", paste(sex_parts, collapse = ", "))

region_parts <- sprintf("%s = %d (%.2f%%)",names(region_counts),as.integer(region_counts), 100 * region_counts / total)
line3 <- paste("region :", paste(region_parts, collapse = ", "))


dementia_parts <- sprintf("%s = %d (%.2f%%)",names(dementia_counts),as.integer(dementia_counts), 100 * dementia_counts / total)
line4 <- paste("dementia types: ", paste(dementia_parts, collapse = ", "))

writeLines(c(line0, line1, line2, line3, line4), "output/table_1.txt")

