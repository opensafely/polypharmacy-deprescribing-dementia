## This script defines possible covariates (predictors of medication reviews and stopping) for the study.
## They are used in table 1 and the survival analysis. Outcomes and censoring dates are in dataset_definition_out.py.
## Variables are defined for each year of the study period to account for possible changes in the values and inclusion

from ehrql.tables.tpp import clinical_events
from ehrql import create_dataset
from ehrql.query_language import table_from_file , PatientFrame, Series
from datetime import date
from analysis.dataset_definition.add_variables import(
    add_covariates,
    add_inex_variables,
    add_frailty_variables
)

# Codelists from codelists.py (which pulls all variables from the codelist folder)
from codelists import *
@table_from_file("output/dataset_clean/input_clean_inex.csv.gz")
class input_inex(PatientFrame):
    qa_num_birth_year = Series(str)

## Create dataset
dataset = create_dataset()

import json
with open("analysis/config.json") as f:
    study_dates = json.load(f)
start_date = study_dates["start_date"]
end_date = study_dates["end_date"]

# Add variables for each year of the study
for year in range(2017, 2025):
    #Add collapsed in/ex variable for each year in the study
    add_inex_variables(dataset, date(year, 1, 1), 1,year)

    # ---------------------------------
    # Create covariates on index date
    add_covariates(dataset, date(year, 1, 1), date(year, 12, 31), year)

    # Frailty variables are disabled until the frailty investigation decides how frailty will be measured
    #add_frailty_variables(dataset, date(year, 1, 1), year)

    # Date of last medication review before the index date (for time since last review)
    cov_dat_last_med_rev = (
        clinical_events.where(clinical_events.snomedct_code.is_in(medication_review_codelist))
        .where(clinical_events.date.is_before(date(year, 1, 1)))
        .sort_by(clinical_events.date)
        .last_for_patient()
        .date)

    dataset.add_column(f"cov_dat_last_med_rev_{year}", cov_dat_last_med_rev)

##Define population
dataset.configure_dummy_data()
dataset.define_population(input_inex.exists_for_patient())
