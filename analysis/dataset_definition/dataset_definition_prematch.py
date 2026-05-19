## This script defines a dataset with variables that will be used to narrow down the full 
## population to those who could potentially be included in the study at any point during the study period. 
## As well as inclusion / exclusion criteria, we also derive criteria for QA 

from ehrql.tables.tpp import patients
from ehrql import create_dataset

from analysis.dataset_definition.add_variables import(
    add_inex_variables_prematch
)

# Codelists from codelists.py (which pulls all variables from the codelist folder)
from codelists import *

## Create dataset
dataset = create_dataset()

#Get study dates
from analysis.dataset_definition.study_dates import *

## ---------------------------------
## Create variables for inclusion / exclusion criteria during the study period
add_inex_variables_prematch(dataset, start_date, end_date)

## ---------------------------------
## Create variables for data quality checks
dataset.qa_num_birth_year = patients.date_of_birth.year
dataset.qa_num_death_year = patients.date_of_death.year

##Define population
dataset.configure_dummy_data()
dataset.define_population(patients.date_of_birth.is_not_null())
