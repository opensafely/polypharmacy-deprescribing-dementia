from ehrql import create_dataset, codelist_from_csv
from ehrql.tables.tpp import patients, practice_registrations, clinical_events, addresses, ethnicity_from_sus, medications

# Codelists from codelists.py (which pulls all variables from the codelist folder)
from codelists import *

##Create dataset
dataset = create_dataset()

##Set start and end date
start_date = "2015-01-01"
end_date = "2024-12-31"

##Derive dataset variables
dataset.sex = patients.sex
dataset.age = patients.age_on(start_date)
dataset.imd = addresses.for_patient_on(start_date).imd_rounded
dataset.region = practice_registrations.for_patient_on(start_date).practice_nuts1_region_name
dataset.ethnicity = ethnicity_from_sus.code

## Medication review variables
dataset.medication_review_yn = (
    clinical_events.where(clinical_events.snomedct_code.is_in(medication_review_codelist))
    .where(clinical_events.date.is_on_or_after(start_date))
    .where(clinical_events.date.is_on_or_before(end_date))
    .exists_for_patient()
)

dataset.first_medication_review_date = (
    clinical_events.where(clinical_events.snomedct_code.is_in(medication_review_codelist))
    .where(clinical_events.date.is_on_or_after(start_date))
    .where(clinical_events.date.is_on_or_before(end_date))
    .sort_by(clinical_events.date)
    .first_for_patient()
    .date)

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

##Derive variables for inclusion / exclusion criteria
aged_65_or_above = dataset.age > 64
multiple_antihypertensive_prescriptions = dataset.number_of_antihypertensive_prescriptions > 1
has_registration = practice_registrations.for_patient_on(start_date).exists_for_patient()

has_dementia = (
    clinical_events.where(clinical_events.snomedct_code.is_in(dementia_codelist))
    .where(clinical_events.date.is_on_or_before(end_date))
    .sort_by(clinical_events.date)
    .last_for_patient()
    ).exists_for_patient()

is_alive = patients.is_alive_on(start_date)
known_sex = patients.sex != "unknown"
known_imd = (dataset.imd >= 0)
known_region = dataset.region != ""

##Define population
dataset.configure_dummy_data(population_size=100)
dataset.define_population(has_registration & has_dementia & aged_65_or_above & is_alive & known_sex & known_imd & known_region & multiple_antihypertensive_prescriptions)

