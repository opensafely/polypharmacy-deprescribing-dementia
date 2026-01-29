## This file loads all the necessary codelists for this project from OpenCodelists 
from ehrql import codelist_from_csv

# Ethnicity
ethnicity_snomed = codelist_from_csv(
  "codelists/opensafely-ethnicity-snomed-0removed.csv",
  column = "code",
  category_column = "Grouping_6"
)

## All dementia codes 
dementia_codelist = codelist_from_csv(
    "codelists/nhsd-primary-care-domain-refsets-dem_cod.csv",
    column="code"
)
## Vascular dementia codes
vascular_dementia_codelist = codelist_from_csv(
    "codelists/nhsd-primary-care-domain-refsets-vascular-dementia-codes.csv",
    column="code"
)
## Alzheimer's codes
alzheimers_codelist = codelist_from_csv(
    "codelists/nhsd-primary-care-domain-refsets-alzheimers-disease-dementia-codes.csv",
    column="code"
)
# Other dementia = codes in general list but not in alz or vasc
other_dementia_codelist = list(
    set(dementia_codelist) - set(alzheimers_codelist).union(vascular_dementia_codelist)
)

## Medication review codes
medication_review_codelist = codelist_from_csv(
    "codelists/nhsd-primary-care-domain-refsets-demmedrvw_cod.csv",
    column="code"
)

## Antihypertensive codes
antihypertensive_codelist = codelist_from_csv(
    "codelists/opensafely-combination-blood-pressure-medication.csv",
    column="code"
)
## ACE-Inhibitor codes
ace_inhibitor_codelist = codelist_from_csv(
    "codelists/opensafely-ace-inhibitor-medications.csv",
    column="code"
)
## Alpha-Adrenoceptor Blocking Drugs codes
alpha_adrenoceptor_blocking_drugs_codelist = codelist_from_csv(
    "codelists/opensafely-alpha-adrenoceptor-blocking-drugs.csv",
    column="code"
)
## Angiotensin II Receptor Blockers (ARBs) codes
angiotensin_ii_receptor_blockers_codelist = codelist_from_csv(
    "codelists/opensafely-angiotensin-ii-receptor-blockers-arbs.csv",
    column="code"
)
## Beta blockers codes
beta_blockers_codelist = codelist_from_csv(
    "codelists/opensafely-beta-blocker-medications.csv",
    column="code"
)
## Calcium channel blockers codes
calcium_channel_blockers_codelist = codelist_from_csv(
    "codelists/opensafely-calcium-channel-blockers.csv",
    column="code"
)

## Centrally acting antihypertensives codes
centrally_acting_antihypertensives_codelist = codelist_from_csv(
    "codelists/user-robert_porteous-centrally-acting-antihypertensives-dmd.csv",
    column="code"
)

## Potassium sparing diuretics codes
potassium_sparing_diuretics_codelist = codelist_from_csv(
    "codelists/user-robert_porteous-potassium-sparing-diuretics-aldosterone-antagonists-and-compounds-dmd.csv",
    column="code"
)

## Chronic Heart Disease codes
chd_codelist = codelist_from_csv(
    "codelists/primis-covid19-vacc-uptake-chd_cov.csv",
    column="code"
)

## Myocardial Infarction codes
mi_codelist = codelist_from_csv(
    "codelists/nhsd-primary-care-domain-refsets-mi_cod.csv",
    column="code"
)

## Stroke codes
strk_codelist = codelist_from_csv(
    "codelists/nhsd-primary-care-domain-refsets-strk_cod.csv",
    column="code"
)

# AMI (Acute Myocardial Infarction)
ami_snomed = codelist_from_csv(
  "codelists/user-elsie_horne-ami_snomed.csv",
  column = "code"
)
ami_icd10 = codelist_from_csv(
  "codelists/user-RochelleKnight-ami_icd10.csv",
  column = "code"
)
ami_prior_icd10 = codelist_from_csv(
  "codelists/user-elsie_horne-ami_prior_icd10.csv",
  column = "code"
)

# Stroke Ischaemic (Ischaemic Stroke)
stroke_isch_snomed = codelist_from_csv(
  "codelists/user-elsie_horne-stroke_isch_snomed.csv",
  column = "code"
)
stroke_isch_icd10 = codelist_from_csv(
  "codelists/user-RochelleKnight-stroke_isch_icd10.csv",
  column = "code"
)

# Cancer
cancer_snomed = codelist_from_csv(
  "codelists/user-elsie_horne-cancer_snomed.csv",
  column = "code"
)
cancer_icd10 = codelist_from_csv(
  "codelists/user-elsie_horne-cancer_icd10.csv",
  column = "code"
)

# Hypertension
hypertension_icd10 = codelist_from_csv(
  "codelists/user-elsie_horne-hypertension_icd10.csv",
  column = "code"
)
hypertension_snomed = codelist_from_csv(
  "codelists/nhsd-primary-care-domain-refsets-hyp_cod.csv",
  column = "code"
)

# Smoking
smoking_clear = codelist_from_csv(
  "codelists/opensafely-smoking-clear.csv",
  column = "CTV3Code",
  category_column = "Category"
)
smoking_unclear = codelist_from_csv(
  "codelists/opensafely-smoking-unclear.csv",
  column = "CTV3Code",
  category_column = "Category"
)
ever_current_smoke = codelist_from_csv(
  "codelists/bristol-smoke-and-eversmoke.csv",
  column = "code"
)