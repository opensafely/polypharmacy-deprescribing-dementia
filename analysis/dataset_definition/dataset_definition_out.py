## This script defines the outcome and follow-up variables for the study.
## The dataset is generated for one study year at a time, pass in as an argument in the yaml.

from analysis.dataset_definition.variable_helper_functions import get_stopping_dates, get_stopping_dates_after_event
from ehrql.tables.tpp import practice_registrations, clinical_events, ons_deaths, patients
from ehrql import create_dataset, minimum_of, get_parameter
from ehrql.query_language import table_from_file , PatientFrame, Series
from datetime import date

# Codelists from codelists.py (which pulls all variables from the codelist folder)
from codelists import *

## Study year for this dataset
year = get_parameter(name="year", type=int)
index_date = date(year, 1, 1)
end_date = date(year, 12, 31)

## Patients eligible on 1 January of the study year
@table_from_file(f"output/dataset_clean/input_clean_inex_{year}.csv.gz")
class input_inex(PatientFrame):
    qa_num_birth_year = Series(int)

## Create dataset
dataset = create_dataset()

# Date of death (for censoring)
dataset.cens_dat_death = minimum_of(patients.date_of_death, ons_deaths.date)

# Deregistration: end of the practice registration active on the index date (for censoring)
dataset.cens_dat_dereg = practice_registrations.for_patient_on(index_date).end_date

# Medication reviews in the year: number of reviews, and date of the first review
med_rev = (clinical_events.where(clinical_events.snomedct_code.is_in(medication_review_codelist))
    .where(clinical_events.date.is_on_or_after(index_date))
    .where(clinical_events.date.is_on_or_before(end_date)))

dataset.out_num_med_rev = med_rev.count_for_patient()
dataset.out_dat_med_rev = med_rev.sort_by(med_rev.date).first_for_patient().date

# Different gap sizes defining stopping events
gap_sizes = [90, 120, 180]

# Date of first stop (gap between prescriptions) in the year for each medication class.
# One call covers all gap sizes, adding columns out_dat_stop_<class>_<gap_size>
stopping_codelists = {
    "acei": ace_inhibitor_codelist,
    "aab": alpha_adrenoceptor_blocking_drugs_codelist,
    "arb": angiotensin_ii_receptor_blockers_codelist,
    "bb": beta_blockers_codelist,
    "ccb": calcium_channel_blockers_codelist,
    "caa": centrally_acting_antihypertensives_codelist,
    "psd": potassium_sparing_diuretics_codelist,
    "ttd": thiazide_type_diuretics_codelist,
}
for drug_class, codelist in stopping_codelists.items():
    get_stopping_dates(dataset, index_date, end_date, codelist, f"out_dat_stop_{drug_class}", limit=52, gap_sizes=gap_sizes)

# Review-based stopping definition (stop identified at a medication review).
# Not run right now but kept for the planned sensitivity analyses:
# Might add in some other definitions too
# for gap_size in gap_sizes:
#     get_stopping_dates_after_event(dataset, index_date, end_date, ace_inhibitor_codelist, medication_review_codelist, f"out_dat_stop_acei_{gap_size}", 10, gap_size)

##Define population
dataset.configure_dummy_data()
dataset.define_population(input_inex.exists_for_patient())
