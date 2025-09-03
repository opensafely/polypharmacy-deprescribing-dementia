from ehrql.tables.tpp import patients, practice_registrations, clinical_events, addresses, ethnicity_from_sus, medications, ons_deaths
from ehrql import create_dataset, codelist_from_csv, days, case, when, minimum_of, show


# Codelists from codelists.py (which pulls all variables from the codelist folder)
from codelists import *

##Create dataset
dataset = create_dataset()

##Set start and end date
start_date = "2015-01-01"
end_date = "2017-12-31"

##Derive dataset covariates
dataset.cov_cat_sex = patients.sex
dataset.cov_num_age = patients.age_on(start_date)
dataset.cov_cat_imd = addresses.for_patient_on(start_date).imd_rounded
dataset.cov_cat_region = practice_registrations.for_patient_on(start_date).practice_nuts1_region_name
dataset.cov_cat_ethnicity = ethnicity_from_sus.code
dataset.qa_num_birth_year = patients.date_of_birth.year

dataset.cov_bin_carehome = (
        addresses.for_patient_on(start_date).care_home_is_potential_match |
        addresses.for_patient_on(start_date).care_home_requires_nursing |
        addresses.for_patient_on(start_date).care_home_does_not_require_nursing
    )

##Create variables for inclusion / exclusion criteria
inex_bin_6m_reg = (practice_registrations.spanning(
        start_date - days(180), start_date
        )).exists_for_patient()

dataset.inex_bin_alive = (((patients.date_of_death.is_null()) | (patients.date_of_death.is_after(start_date))) & 
    ((ons_deaths.date.is_null()) | (ons_deaths.date.is_after(start_date))))

dataset.inex_bin_has_dementia = (
    clinical_events.where(clinical_events.snomedct_code.is_in(dementia_codelist))
    .where(clinical_events.date.is_on_or_before(end_date))
    .sort_by(clinical_events.date)
    .last_for_patient()
    ).exists_for_patient()

dataset.inex_bin_long_term_antihypertensive_user = (medications.where(medications.dmd_code.is_in(antihypertensive_codelist))
    .where(medications.date.is_on_or_before(start_date - days (365)))
    .where(medications.date.is_on_or_after(start_date))
    .count_for_patient()) > 2

##Yes/No variables for prescriptions in each month
for i in range(37):
    medication_yn = (medications.where(medications.dmd_code.is_in(antihypertensive_codelist))
    .where(medications.date.is_on_or_before(start_date + days(30 * i)))
    .where(medications.date.is_on_or_after(start_date + days(30 * (i-1))))
    .sort_by(medications.date)
    .exists_for_patient())
    dataset.add_column(f"Month_{i}_med", medication_yn)




# ---NOT USING THESE YET---
##Most recent dementia codes
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

##Medication variables
dataset.number_of_antihypertensive_prescriptions = (medications.where(medications.dmd_code.is_in(antihypertensive_codelist))
    .where(medications.date.is_on_or_before(end_date))
    .where(medications.date.is_on_or_after(start_date))
    .count_for_patient())

## Medication review variables
dataset.cov_bin_medication_review_yn = (
    clinical_events.where(clinical_events.snomedct_code.is_in(medication_review_codelist))
    .where(clinical_events.date.is_on_or_after(start_date))
    .where(clinical_events.date.is_on_or_before(end_date))
    .exists_for_patient()
)

##Derive variables for inclusion / exclusion criteria (not using these rn)
#aged_65_or_above = dataset.cov_num_age > 64
#multiple_antihypertensive_prescriptions = dataset.number_of_antihypertensive_prescriptions > 1
#has_registration = practice_registrations.for_patient_on(start_date).exists_for_patient()
#is_alive = patients.is_alive_on(start_date)
#known_sex = patients.sex != "unknown"
#known_imd = (dataset.cov_cat_imd >= 0)
#known_region = dataset.cov_cat_region != ""

##Define population
dataset.configure_dummy_data(population_size=100)
dataset.define_population(patients.date_of_birth.is_not_null())
##dataset.define_population(has_registration & has_dementia & aged_65_or_above & is_alive & known_sex & known_imd & known_region & multiple_antihypertensive_prescriptions)
