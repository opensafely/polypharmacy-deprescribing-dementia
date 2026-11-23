## This script defines the variables used for the prescription gap histograms
## This code is run once per study yuear as separate actions in the yaml

from ehrql.tables.tpp import practice_registrations
from ehrql import create_dataset, get_parameter
from ehrql.query_language import table_from_file , PatientFrame, Series
from datetime import date
from analysis.dataset_definition.variable_helper_functions import (
    get_prescription_gaps
)
from analysis.dataset_definition.add_variables import antihypertensive_class_codelists

# Codelists from codelists.py (which pulls all variables from the codelist folder)
from codelists import *

## Study year for this dataset
year = get_parameter(name="year", type=int)
index_date = date(year, 1, 1)
end_date = date(year, 12, 31)

## Patients eligible on 1 January of the study year
@table_from_file(f"output/dataset_clean/input_clean_inex_{year}.csv.gz")
class input_inex(PatientFrame):
    qa_num_birth_year = Series(str)

# Maximum number of prescriptions to step through in the year
# (52 covers weekly prescribing)
limit = 52

## Create dataset
dataset = create_dataset()

dataset.cov_cat_region = practice_registrations.for_patient_on(index_date).practice_nuts1_region_name

## Outcome Variables - Gaps between prescriptions of each medication class
for drug_class, codelist in antihypertensive_class_codelists.items():
    get_prescription_gaps(dataset, index_date, end_date, codelist, drug_class, limit)

##Define population
dataset.configure_dummy_data()
dataset.define_population(input_inex.exists_for_patient())
