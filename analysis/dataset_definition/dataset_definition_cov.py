## This script defines possible covariates (predictors of medication reviews and stopping) for the study.
## They are used in table 1 and the survival analysis. Outcomes and censoring dates are in dataset_definition_out.py.
##
## The dataset is generated for one study year at a time, passed in the yaml.
## The population is everyone in that year's cleaned inex dataset (eligible on 1 January of that year).

from ehrql.tables.tpp import clinical_events
from ehrql import create_dataset, get_parameter
from ehrql.query_language import table_from_file , PatientFrame, Series
from datetime import date
from analysis.dataset_definition.add_variables import(
    add_covariates,
    add_frailty_variables
)

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

## Create dataset
dataset = create_dataset()

# ---------------------------------
# Create covariates on index date
add_covariates(dataset, index_date, end_date)

# Frailty variables are commented out until I decide on how I'm going to use these.
#add_frailty_variables(dataset, index_date)

# Date of last medication review before the index date (for time since last review)
dataset.cov_dat_last_med_rev = (
    clinical_events.where(clinical_events.snomedct_code.is_in(medication_review_codelist))
    .where(clinical_events.date.is_before(index_date))
    .sort_by(clinical_events.date)
    .last_for_patient()
    .date)

##Define population
dataset.configure_dummy_data()
dataset.define_population(input_inex.exists_for_patient())
