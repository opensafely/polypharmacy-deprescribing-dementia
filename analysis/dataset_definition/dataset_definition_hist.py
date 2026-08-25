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

#Get study dates
import json
with open("analysis/config.json") as f:
    study_dates = json.load(f)
start_date = study_dates["start_date"]
end_date = study_dates["end_date"]

index_date = start_date
limit = 26

# Add inex variables for 2015 through 2024
for year in range(2017, 2025):
    #Add collapsed in/ex variable for each year in the study
    add_inex_variables(dataset, date(year, 1, 1), 1,year)

    region = practice_registrations.for_patient_on(date(year, 1, 1)).practice_nuts1_region_name
    dataset.add_column(f"desc_cat_region{year}", region)

    ## Outcome Variables - Gaps between prescriptions of each medication class
    get_prescription_gaps(dataset, date(year, 1, 1),date(year, 12, 31), ace_inhibitor_codelist, f"acei_{year}", limit)
    get_prescription_gaps(dataset, date(year, 1, 1),date(year, 12, 31), alpha_adrenoceptor_blocking_drugs_codelist, f"aab_{year}", limit)
    get_prescription_gaps(dataset, date(year, 1, 1),date(year, 12, 31), angiotensin_ii_receptor_blockers_codelist, f"arb_{year}", limit)
    get_prescription_gaps(dataset, date(year, 1, 1),date(year, 12, 31), beta_blockers_codelist, f"bb_{year}", limit)
    get_prescription_gaps(dataset, date(year, 1, 1),date(year, 12, 31), calcium_channel_blockers_codelist, f"ccb_{year}", limit)
    get_prescription_gaps(dataset, date(year, 1, 1),date(year, 12, 31), centrally_acting_antihypertensives_codelist, f"caa_{year}", limit)
    get_prescription_gaps(dataset, date(year, 1, 1),date(year, 12, 31), potassium_sparing_diuretics_codelist, f"psd_{year}", limit)
    get_prescription_gaps(dataset, date(year, 1, 1),date(year, 12, 31), thiazide_type_diuretics_codelist, f"ttd_{year}", limit)

# ---------------------------------
# Create covariates on index date
add_covariates(dataset, index_date, end_date)

# Medication review variables
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
