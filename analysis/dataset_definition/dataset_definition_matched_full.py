from ehrql.tables.tpp import patients, practice_registrations, clinical_events, addresses, ethnicity_from_sus, medications, ons_deaths, apcs, decision_support_values, emergency_care_attendances
from ehrql import create_dataset, codelist_from_csv, days, case, when, minimum_of, show
from ehrql.query_language import table_from_file , PatientFrame, Series
from datetime import datetime, date

from analysis.dataset_definition.add_variables import(
    add_inex_variables,
    add_covariates,
    add_out_variables
)

# Codelists from codelists.py (which pulls all variables from the codelist folder)
from codelists import *

@table_from_file("output/dataset_clean/input_clean_inex_matched.csv")
class input_matched(PatientFrame):
    index_date = Series(date)

## Create dataset
dataset = create_dataset()

#Get study dates
from analysis.dataset_definition.study_dates import *

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


## ---------------------------------
## Create covariates on index date
add_covariates(dataset, input_matched.index_date, end_date)

## Outcome Variables
#This function needs tweaking - to be done in a later push
#add_out_variables(dataset, index_date, start_date, end_date, ace_inhibitor_codelist, "acei")
#add_out_variables(dataset, index_date, start_date, end_date, alpha_adrenoceptor_blocking_drugs_codelist, "aab")
#add_out_variables(dataset, index_date, start_date, end_date, angiotensin_ii_receptor_blockers_codelist, "arb")


##Define population
dataset.configure_dummy_data(population_size=1000)
dataset.define_population(input_matched.exists_for_patient())
