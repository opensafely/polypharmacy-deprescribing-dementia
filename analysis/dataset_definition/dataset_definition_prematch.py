from ehrql.tables.tpp import patients, practice_registrations, clinical_events, addresses, ethnicity_from_sus, medications, ons_deaths, apcs, decision_support_values, emergency_care_attendances
from ehrql import create_dataset, codelist_from_csv, days, case, when, minimum_of, show
from datetime import datetime, date

from analysis.dataset_definition.add_variables import(
    add_inex_variables
)
# Codelists from codelists.py (which pulls all variables from the codelist folder)
from codelists import *

## Create dataset
dataset = create_dataset()

#Get study dates
from analysis.dataset_definition.study_dates import *

## ---------------------------------
## Create variables for inclusion / exclusion criteria at the start of the study period
add_inex_variables(dataset, start_date)

## ---------------------------------
## Create variables for data quality checks
dataset.qa_num_birth_year = patients.date_of_birth.year
dataset.qa_num_death_year = patients.date_of_death.year

##Define population
dataset.configure_dummy_data()
dataset.define_population(patients.date_of_birth.is_not_null())
