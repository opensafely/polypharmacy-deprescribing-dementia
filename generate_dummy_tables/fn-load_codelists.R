library(readr)
library(dplyr)

# Ethnicity
ethnicity_snomed <- read_csv("codelists/opensafely-ethnicity-snomed-0removed.csv") %>%
  select(code, Grouping_6)

# All dementia codes
dementia_codelist_snomed <- read_csv("codelists/nhsd-primary-care-domain-refsets-dem_cod.csv") %>%
  select(code)

# Vascular dementia codes
vascular_dementia_codelist_snomed <- read_csv("codelists/nhsd-primary-care-domain-refsets-vascular-dementia-codes.csv") %>%
  select(code)

# Alzheimer's codes
alzheimers_codelist_snomed <- read_csv("codelists/nhsd-primary-care-domain-refsets-alzheimers-disease-dementia-codes.csv") %>%
  select(code)

# Other dementia = codes in general list but not in alz or vasc
other_dementia_codelist_snomed <- setdiff(dementia_codelist_snomed, union(alzheimers_codelist_snomed, vascular_dementia_codelist_snomed))

# Medication review codes
medication_review_codelist_snomed <- read_csv("codelists/nhsd-primary-care-domain-refsets-demmedrvw_cod.csv") %>%
  select(code)

# Antihypertensive codes
antihypertensive_codelist_dmd <- read_csv("codelists/opensafely-combination-blood-pressure-medication.csv") %>%
  select(code)

# ACE-Inhibitor codes
ace_inhibitor_codelist_dmd <- read_csv("codelists/opensafely-ace-inhibitor-medications.csv") %>%
  select(code)

# Alpha-Adrenoceptor Blocking Drugs codes
alpha_adrenoceptor_blocking_drugs_codelist_dmd <- read_csv("codelists/opensafely-alpha-adrenoceptor-blocking-drugs.csv") %>%
  select(code)

# Angiotensin II Receptor Blockers (ARBs) codes
angiotensin_ii_receptor_blockers_codelist_dmd <- read_csv("codelists/opensafely-angiotensin-ii-receptor-blockers-arbs.csv") %>%
  select(code)

# Beta blockers codes
beta_blockers_codelist_dmd <- read_csv("codelists/opensafely-beta-blocker-medications.csv") %>%
  select(code)

# Calcium channel blockers codes
calcium_channel_blockers_codelist_dmd <- read_csv("codelists/opensafely-calcium-channel-blockers.csv") %>%
  select(code)

# Chronic Heart Disease codes
chd_codelist_snomed <- read_csv("codelists/primis-covid19-vacc-uptake-chd_cov.csv") %>%
  select(code)

# Myocardial Infarction codes
mi_codelist_snomed <- read_csv("codelists/nhsd-primary-care-domain-refsets-mi_cod.csv") %>%
  select(code)

# Stroke codes
strk_codelist_snomed <- read_csv("codelists/nhsd-primary-care-domain-refsets-strk_cod.csv") %>%
  select(code)

# AMI (Acute Myocardial Infarction)
ami_snomed <- read_csv("codelists/user-elsie_horne-ami_snomed.csv") %>% select(code)
ami_icd10 <- read_csv("codelists/user-RochelleKnight-ami_icd10.csv") %>% select(code)
ami_prior_icd10 <- read_csv("codelists/user-elsie_horne-ami_prior_icd10.csv") %>% select(code)

# Stroke Ischaemic (Ischaemic Stroke)
stroke_isch_snomed <- read_csv("codelists/user-elsie_horne-stroke_isch_snomed.csv") %>% select(code)
stroke_isch_icd10 <- read_csv("codelists/user-RochelleKnight-stroke_isch_icd10.csv") %>% select(code)

# Cancer
cancer_snomed <- read_csv("codelists/user-elsie_horne-cancer_snomed.csv") %>% select(code)
cancer_icd10 <- read_csv("codelists/user-elsie_horne-cancer_icd10.csv") %>% select(code)

# Hypertension
hypertension_icd10 <- read_csv("codelists/user-elsie_horne-hypertension_icd10.csv") %>% select(code)
hypertension_snomed <- read_csv("codelists/nhsd-primary-care-domain-refsets-hyp_cod.csv") %>% select(code)

# Smoking
smoking_clear_CTV3 <- read_csv("codelists/opensafely-smoking-clear.csv") %>%
  select(CTV3Code, Category)
smoking_unclear_CTV3 <- read_csv("codelists/opensafely-smoking-unclear.csv") %>%
  select(CTV3Code, Category)
ever_current_smoke_CTV3 <- read_csv("codelists/bristol-smoke-and-eversmoke.csv") %>% select(code)


# Function to rename code column if it exists
rename_snmed <- function(df) {
  if ("code" %in% colnames(df)) {
    df <- df %>% rename(snomedct_code = code)
  }
  return(df)
}

# Find all variables with "_snomed" in their name
snmed_vars <- ls(pattern = "_snomed$")

# Loop over them and rename their code column
for (var in snmed_vars) {
  df <- get(var)
  df <- rename_snmed(df)
  assign(var, df)
}
