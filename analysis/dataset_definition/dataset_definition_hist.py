from ehrql.tables.tpp import clinical_events
from ehrql import create_dataset
from ehrql.query_language import table_from_file , PatientFrame, Series
from datetime import datetime, date
from analysis.dataset_definition.variable_helper_functions import (
    get_prescription_gaps
)
from analysis.dataset_definition.add_variables import(
    add_covariates,
)


# Codelists from codelists.py (which pulls all variables from the codelist folder)
from codelists import *
@table_from_file("output/dataset_clean/input_clean_prematch.csv.gz")
class input_inex(PatientFrame):
    qa_num_birth_year = Series(str)

## Create dataset
dataset = create_dataset()

#Get study dates
from analysis.dataset_definition.study_dates import *

index_date = start_date

## Outcome Variables
limit = 10
get_prescription_gaps(dataset, start_date, end_date, ace_inhibitor_codelist, "acei", limit)
get_prescription_gaps(dataset, start_date, end_date, alpha_adrenoceptor_blocking_drugs_codelist, "aab", limit)
get_prescription_gaps(dataset, start_date, end_date, angiotensin_ii_receptor_blockers_codelist, "arb", limit)
get_prescription_gaps(dataset, start_date, end_date, beta_blockers_codelist, "bb", limit)
get_prescription_gaps(dataset, start_date, end_date, calcium_channel_blockers_codelist, "ccb", limit)
get_prescription_gaps(dataset, start_date, end_date, centrally_acting_antihypertensives_codelist, "caa", limit)
get_prescription_gaps(dataset, start_date, end_date, potassium_sparing_diuretics_codelist, "psd", limit)


## ---------------------------------
## Create covariates on index date
add_covariates(dataset, index_date, end_date)

## Medication review variables
dataset.exp_dat_med_rev = (
    clinical_events.where(clinical_events.snomedct_code.is_in(medication_review_codelist))
    .where(clinical_events.date.is_on_or_after(start_date))
    .where(clinical_events.date.is_on_or_before(end_date))
    .sort_by(clinical_events.date)
    .first_for_patient()
    .date)

##Define population
dataset.configure_dummy_data()
dataset.define_population(input_inex.exists_for_patient())
