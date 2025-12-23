from ehrql.tables.tpp import patients, practice_registrations, clinical_events, addresses, ethnicity_from_sus, medications, ons_deaths, apcs, decision_support_values, emergency_care_attendances
from ehrql import create_dataset, codelist_from_csv, days, case, when, minimum_of, show
from ehrql.query_language import table_from_file , PatientFrame, Series
from datetime import datetime, date

from analysis.dataset_definition.add_variables import(
    add_inex_variables
)

# Codelists from codelists.py (which pulls all variables from the codelist folder)
from codelists import *

@table_from_file("output/dataset_clean/input_matched.csv")
class input_inex(PatientFrame):
    index_date = Series(date)

## Create dataset
dataset = create_dataset()

#Get study dates
from analysis.dataset_definition.study_dates import *

## ---------------------------------
## Create variables for inclusion / exclusion criteria at the start of the study period
add_inex_variables(dataset, input_inex.index_date)

## ---------------------------------
## Create variables for data quality checks
dataset.qa_num_birth_year = patients.date_of_birth.year
dataset.qa_num_death_year = patients.date_of_death.year
dataset.index_date = input_inex.index_date

##Define population
dataset.configure_dummy_data(population_size=1000)
dataset.define_population(input_inex.exists_for_patient())
