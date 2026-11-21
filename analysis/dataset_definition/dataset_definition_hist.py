## This script defines the variables used for the prescription gap histograms:
## counts of gaps of different lengths between consecutive prescriptions of each medication class,
## and the practice region for the regional breakdown.
##
## The dataset is generated for one study year at a time, pass as an argument in the yaml

from ehrql.tables.tpp import practice_registrations
from ehrql import create_dataset, get_parameter
from ehrql.query_language import table_from_file , PatientFrame, Series
from datetime import date
from analysis.dataset_definition.variable_helper_functions import (
    get_prescription_gaps
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

# Maximum number of prescriptions to step through in the year
# (52 covers weekly prescribing)
limit = 52

## Create dataset
dataset = create_dataset()

dataset.cov_cat_region = practice_registrations.for_patient_on(index_date).practice_nuts1_region_name

## Outcome Variables - Gaps between prescriptions of each medication class
get_prescription_gaps(dataset, index_date, end_date, ace_inhibitor_codelist, "acei", limit)
get_prescription_gaps(dataset, index_date, end_date, alpha_adrenoceptor_blocking_drugs_codelist, "aab", limit)
get_prescription_gaps(dataset, index_date, end_date, angiotensin_ii_receptor_blockers_codelist, "arb", limit)
get_prescription_gaps(dataset, index_date, end_date, beta_blockers_codelist, "bb", limit)
get_prescription_gaps(dataset, index_date, end_date, calcium_channel_blockers_codelist, "ccb", limit)
get_prescription_gaps(dataset, index_date, end_date, centrally_acting_antihypertensives_codelist, "caa", limit)
get_prescription_gaps(dataset, index_date, end_date, potassium_sparing_diuretics_codelist, "psd", limit)
get_prescription_gaps(dataset, index_date, end_date, thiazide_type_diuretics_codelist, "ttd", limit)

##Define population
dataset.configure_dummy_data()
dataset.define_population(input_inex.exists_for_patient())
