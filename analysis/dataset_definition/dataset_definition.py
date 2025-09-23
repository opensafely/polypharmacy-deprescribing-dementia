from ehrql.tables.tpp import patients, practice_registrations, clinical_events, addresses, ethnicity_from_sus, medications, ons_deaths
from ehrql import create_dataset, codelist_from_csv, days, case, when, minimum_of, show


# Codelists from codelists.py (which pulls all variables from the codelist folder)
from codelists import *

## Create dataset
dataset = create_dataset()

## Set start and end date (only looking at first period for now)
start_date = "2015-01-01"
end_date = "2020-03-01"

## ---------------------------------
##Create variables for inclusion / exclusion criteria

# Dementia diagnosis
dataset.inex_bin_has_dementia = (
    clinical_events.where(clinical_events.snomedct_code.is_in(dementia_codelist))
    .where(clinical_events.date.is_on_or_before(end_date))
    .sort_by(clinical_events.date)
    .last_for_patient()
    ).exists_for_patient()

# Long-term antihypertensive user 
dataset.inex_bin_long_term_antihypertensive_user = (medications.where(medications.dmd_code.is_in(antihypertensive_codelist))
    .where(medications.date.is_on_or_before(start_date - days (365)))
    .where(medications.date.is_on_or_after(start_date))
    .count_for_patient()) > 2

# Alive at start date
dataset.inex_bin_alive = (((patients.date_of_death.is_null()) | (patients.date_of_death.is_after(start_date))) & 
    ((ons_deaths.date.is_null()) | (ons_deaths.date.is_after(start_date))))

#65 or over at start date
dataset.inex_bin_over_65 = patients.age_on(start_date)>64

# Registered with practice at within 6 months of start date
dataset.inex_bin_6m_reg = (practice_registrations.spanning(
        start_date - days(180), start_date
        )).exists_for_patient()

#Known sex
dataset.inex_bin_known_sex = patients.sex != "unknown"
#Known IMD
dataset.inex_bin_known_imd = (addresses.for_patient_on(start_date).imd_rounded >= 0)
#Known region
dataset.inex_bin_known_region = practice_registrations.for_patient_on(start_date).practice_nuts1_region_name != ""


## ---------------------------------
## Create variables for data quality checks
dataset.qa_num_birth_year = patients.date_of_birth.year
dataset.qa_num_death_year = patients.date_of_death.year

## ---------------------------------
## Create covariates
dataset.cov_num_age = patients.age_on(start_date)
dataset.cov_cat_sex = patients.sex
dataset.cov_cat_ethnicity = ethnicity_from_sus.code
dataset.cov_cat_imd = addresses.for_patient_on(start_date).imd_rounded
dataset.cov_cat_region = practice_registrations.for_patient_on(start_date).practice_nuts1_region_name

# Date of first dementia diagnosis
dataset.cov_dat_dementia_diagnosis_date = (
    clinical_events.where(clinical_events.snomedct_code.is_in(dementia_codelist))
    .where(clinical_events.date.is_on_or_before(end_date))
    .sort_by(clinical_events.date)
    .first_for_patient()
    .date)

#Date of CHD diagnosis
dataset.cov_dat_chd_diagnosis_date = (
    clinical_events.where(clinical_events.snomedct_code.is_in(chd_codelist))
    .where(clinical_events.date.is_on_or_before(end_date))
    .sort_by(clinical_events.date)
    .first_for_patient()
    .date)

# Care home status
dataset.cov_bin_carehome = (
        addresses.for_patient_on(start_date).care_home_is_potential_match |
        addresses.for_patient_on(start_date).care_home_requires_nursing |
        addresses.for_patient_on(start_date).care_home_does_not_require_nursing
    )


## ---------------------------------
## Exposure and outcome variables to be added later

##Define population
dataset.configure_dummy_data(population_size=100)
dataset.define_population(patients.date_of_birth.is_not_null())




# ---NOT USING THESE RIGHT NOW---
#Most recent dementia codes
dataset.latest_dementia_code = (
    clinical_events.where(clinical_events.snomedct_code.is_in(dementia_codelist))
    .where(clinical_events.date.is_on_or_before(end_date))
    .sort_by(clinical_events.date)
    .last_for_patient()
    .snomedct_code)
dataset.latest_alzheimers_code = (clinical_events.where(clinical_events.snomedct_code.is_in(alzheimers_codelist))
    .where(clinical_events.date.is_on_or_before(end_date))
    .sort_by(clinical_events.date)
    .last_for_patient()
    .snomedct_code)
dataset.latest_vascular_dementia_code = (clinical_events.where(clinical_events.snomedct_code.is_in(vascular_dementia_codelist))
    .where(clinical_events.date.is_on_or_before(end_date))
    .sort_by(clinical_events.date)
    .last_for_patient()
    .snomedct_code)
dataset.latest_other_dementia_code = (clinical_events.where(clinical_events.snomedct_code.is_in(other_dementia_codelist))
    .where(clinical_events.date.is_on_or_before(end_date))
    .sort_by(clinical_events.date)
    .last_for_patient()
    .snomedct_code)

# ##Medication variables
# dataset.number_of_antihypertensive_prescriptions = (medications.where(medications.dmd_code.is_in(antihypertensive_codelist))
#     .where(medications.date.is_on_or_before(end_date))
#     .where(medications.date.is_on_or_after(start_date))
#     .count_for_patient())

# ## Medication review variables
# dataset.cov_bin_medication_review_yn = (
#     clinical_events.where(clinical_events.snomedct_code.is_in(medication_review_codelist))
#     .where(clinical_events.date.is_on_or_after(start_date))
#     .where(clinical_events.date.is_on_or_before(end_date))
#     .exists_for_patient()
# )

##Yes/No variables for prescriptions in each month
#for i in range(37):
#    medication_yn = (medications.where(medications.dmd_code.is_in(antihypertensive_codelist))
#    .where(medications.date.is_on_or_before(start_date + days(30 * i)))
#    .where(medications.date.is_on_or_after(start_date + days(30 * (i-1))))
#    .sort_by(medications.date)
#    .exists_for_patient())
#    dataset.add_column(f"Month_{i}_med", medication_yn)

##Derive variables for inclusion / exclusion criteria (not using these rn)
#aged_65_or_above = dataset.cov_num_age > 64
#multiple_antihypertensive_prescriptions = dataset.number_of_antihypertensive_prescriptions > 1
#has_registration = practice_registrations.for_patient_on(start_date).exists_for_patient()
#is_alive = patients.is_alive_on(start_date)
#known_sex = patients.sex != "unknown"



