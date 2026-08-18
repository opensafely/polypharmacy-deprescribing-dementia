## This script defines possible covariates for the analysis section of the study.
## For now these will be presented in table 1 format to be used in the descriptive section of the study.
## Variables are defined for each year of the study period to account for possible changes in the values and inclusion

from ehrql.tables.tpp import clinical_events, practice_registrations
from ehrql import create_dataset
from ehrql.query_language import table_from_file , PatientFrame, Series
from datetime import datetime, date
from analysis.dataset_definition.variable_helper_functions import (
    get_prescription_gaps
)
from analysis.dataset_definition.add_variables import(
    add_covariates,
    add_inex_variables,
)


# Codelists from codelists.py (which pulls all variables from the codelist folder)
from codelists import *
@table_from_file("output/dataset_clean/input_clean_prematch.csv.gz")
class input_inex(PatientFrame):
    qa_num_birth_year = Series(str)

## Create dataset
dataset = create_dataset()

import json
with open("analysis/config.json") as f:
    study_dates = json.load(f)
start_date = study_dates["start_date"]
end_date = study_dates["end_date"]

index_date = start_date
limit = 2

# Add inex variables for 2015 through 2024
for year in range(2017, 2025):
    #Add collapsed in/ex variable for each year in the study
    add_inex_variables(dataset, date(year, 1, 1), 1,year)

    # ---------------------------------
    # Create covariates on index date
    add_covariates(dataset, date(year, 1, 1), date(year, 12, 31), year)

    # Medication review variables
    exp_dat_med_rev = (
        clinical_events.where(clinical_events.snomedct_code.is_in(medication_review_codelist))
        .where(clinical_events.date.is_on_or_after(date(year, 1, 1)))
        .where(clinical_events.date.is_on_or_before(date(year, 12, 31)))
        .sort_by(clinical_events.date)
        .first_for_patient()
        .date)
    
    dataset.add_column(f"exp_dat_med_rev_{year}", exp_dat_med_rev)

##Define population
dataset.configure_dummy_data()
dataset.define_population(input_inex.exists_for_patient())
