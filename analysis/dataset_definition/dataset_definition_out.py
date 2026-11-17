## This script defines the outcome and follow-up variables for the study.
## Key variables defined are:
## - Number of medication reviews each patient has in each year of the study
## - Date of first medication review for each year of the study period
## - Date of the first "stopping" event for each drug in each year of the study based on different stopping definitions
## - Censoring dates (death, and deregistration from the practice registered with at the start of each year)

from analysis.dataset_definition.variable_helper_functions import get_stopping_dates, get_stopping_dates_after_event
from ehrql.tables.tpp import practice_registrations, clinical_events, ons_deaths, patients
from ehrql import create_dataset, minimum_of
from ehrql.query_language import table_from_file , PatientFrame, Series
from datetime import date

from analysis.dataset_definition.add_variables import(
    add_inex_variables)

# Codelists from codelists.py (which pulls all variables from the codelist folder)
from codelists import *
@table_from_file("output/dataset_clean/input_clean_inex.csv.gz")
class input_inex(PatientFrame):
    qa_num_birth_year = Series(int)


## Create dataset
dataset = create_dataset()

#Get study dates
import json
with open("analysis/config.json") as f:
    study_dates = json.load(f)
start_date = study_dates["start_date"]
end_date = study_dates["end_date"]

# Date of death (for censoring) - not year-specific
dataset.add_column("cens_dat_death", minimum_of(patients.date_of_death, ons_deaths.date))

# Different gap sizes defining stopping events
gap_sizes = [90, 120, 180]

# Add variables for each year of the study
for year in range(2017, 2025):
    #Add collapsed in/ex variable for each year in the study
    add_inex_variables(dataset, date(year, 1, 1), 1,year)

    # Medication reviews in the year: number of reviews, and date of the first review
    med_rev = (clinical_events.where(clinical_events.snomedct_code.is_in(medication_review_codelist))
        .where(clinical_events.date.is_on_or_after(date(year, 1, 1)))
        .where(clinical_events.date.is_on_or_before(date(year, 12, 31))))

    dataset.add_column(f"out_num_med_rev_{year}", med_rev.count_for_patient())
    dataset.add_column(f"out_dat_med_rev_{year}", med_rev.sort_by(med_rev.date).first_for_patient().date)

    # Add variables for date of first stop (gap between prescriptions) for each year for each medication class.
    # One call covers all gap sizes, adding columns out_dat_stop_<class>_<gap_size>_<year>
    get_stopping_dates(dataset, date(year, 1, 1), date(year, 12, 31), ace_inhibitor_codelist, "out_dat_stop_acei", year, 15, gap_sizes)
    get_stopping_dates(dataset, date(year, 1, 1), date(year, 12, 31), alpha_adrenoceptor_blocking_drugs_codelist, "out_dat_stop_aab", year, 15, gap_sizes)
    get_stopping_dates(dataset, date(year, 1, 1), date(year, 12, 31), angiotensin_ii_receptor_blockers_codelist, "out_dat_stop_arb", year, 15, gap_sizes)
    get_stopping_dates(dataset, date(year, 1, 1), date(year, 12, 31), beta_blockers_codelist, "out_dat_stop_bb", year, 15, gap_sizes)
    get_stopping_dates(dataset, date(year, 1, 1), date(year, 12, 31), calcium_channel_blockers_codelist, "out_dat_stop_ccb", year, 15, gap_sizes)
    get_stopping_dates(dataset, date(year, 1, 1), date(year, 12, 31), centrally_acting_antihypertensives_codelist, "out_dat_stop_caa", year, 15, gap_sizes)
    get_stopping_dates(dataset, date(year, 1, 1), date(year, 12, 31), potassium_sparing_diuretics_codelist, "out_dat_stop_psd", year, 15, gap_sizes)
    get_stopping_dates(dataset, date(year, 1, 1), date(year, 12, 31), thiazide_type_diuretics_codelist, "out_dat_stop_ttd", year, 15, gap_sizes)

    # Review-based stopping definition (stop identified at a medication review).
    # Not run right now but kept for the planned sensitivity analyses:
    # for gap_size in gap_sizes:
    #     get_stopping_dates_after_event(dataset, date(year, 1, 1), date(year, 12, 31), ace_inhibitor_codelist, medication_review_codelist, f"out_dat_stop_acei_{gap_size}_{year}", 10, gap_size)

    # Deregistration: end of the practice registration active on the index date (for censoring)
    dataset.add_column(f"cens_dat_dereg_{year}", practice_registrations.for_patient_on(date(year, 1, 1)).end_date)

##Define population
dataset.configure_dummy_data()
dataset.define_population(input_inex.exists_for_patient())
