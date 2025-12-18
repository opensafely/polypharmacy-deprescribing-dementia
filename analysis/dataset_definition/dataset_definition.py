from ehrql.tables.tpp import patients, practice_registrations, clinical_events, addresses, medications, ons_deaths, apcs, decision_support_values, emergency_care_attendances
from ehrql import create_dataset, codelist_from_csv, days, case, when, minimum_of, show
from datetime import datetime, date
from analysis.dataset_definition.variable_helper_functions import (
    get_prescription_dates, 
    get_prescription_gaps,
    last_matching_event_clinical_snomed_before,
    last_matching_event_apc_before,
    last_matching_event_clinical_ctv3_before,
    ever_matching_event_clinical_ctv3_before,
    filter_codes_by_category
)
from analysis.dataset_definition.create_variables import(
    add_inex_variables,
    add_covariates,
    add_out_variables
)

# Codelists from codelists.py (which pulls all variables from the codelist folder)
from codelists import *

## Create dataset
dataset = create_dataset()

## Set start and end date (only looking at first year for now)
start_date = date(2015,1,1)
end_date = date(2020,3,1)

## ---------------------------------
## Exposure variable

## Medication review variables
dataset.exp_dat_med_rev = (
    clinical_events.where(clinical_events.snomedct_code.is_in(medication_review_codelist))
    .where(clinical_events.date.is_on_or_after(start_date))
    .where(clinical_events.date.is_on_or_before(end_date))
    .sort_by(clinical_events.date)
    .first_for_patient()
    .date)

dataset.exp_bin_med_rev = (
    clinical_events.where(clinical_events.snomedct_code.is_in(medication_review_codelist))
    .where(clinical_events.date.is_on_or_after(start_date))
    .where(clinical_events.date.is_on_or_before(end_date))
    .exists_for_patient())

dataset.exp_dat_first_event = (
    clinical_events
    .where(clinical_events.date.is_on_or_after(start_date))
    .where(clinical_events.date.is_on_or_before(end_date))
    .sort_by(clinical_events.date)
    .first_for_patient()
    .date
)
dataset.exp_bin_first_event = (
    clinical_events
    .where(clinical_events.date.is_on_or_after(start_date))
    .where(clinical_events.date.is_on_or_before(end_date))
    .exists_for_patient()
)

#Create index dates

index_date = case(
    when(dataset.exp_bin_med_rev).then(dataset.exp_dat_med_rev),
    when(dataset.exp_bin_first_event).then(dataset.exp_dat_first_event),
    otherwise=start_date
)

dataset.index_date = index_date

## ---------------------------------
## Create variables for inclusion / exclusion criteria at the start of the study period
add_inex_variables(dataset, start_date)

## ---------------------------------
## Create variables for data quality checks
dataset.qa_num_birth_year = patients.date_of_birth.year
dataset.qa_num_death_year = patients.date_of_death.year

## ---------------------------------
## Create covariates on index date
add_covariates(dataset, index_date, end_date)

## Outcome Variables
add_out_variables(dataset, index_date, start_date, end_date, ace_inhibitor_codelist, "acei")
add_out_variables(dataset, index_date, start_date, end_date, alpha_adrenoceptor_blocking_drugs_codelist, "aab")
add_out_variables(dataset, index_date, start_date, end_date, angiotensin_ii_receptor_blockers_codelist, "arb")


##Define population
dataset.configure_dummy_data(population_size=1000)
dataset.define_population(patients.date_of_birth.is_not_null())
