## This script defines the dataset for the descriptive analysis of the study.
## Key variables defined are:
## - Number of medication reviews each patient has in each year of the study
## - Date of first medication review for each year of the study period
## - Date of the first "stopping" event for each drug in each year of the study based on different stopping definitions
## - Region of the patient's practice for regional analysis 

from analysis.dataset_definition.variable_helper_functions import get_stopping_dates_after_event
from ehrql.tables.tpp import practice_registrations, clinical_events
from ehrql import create_dataset, days
from ehrql.query_language import table_from_file , PatientFrame, Series
from datetime import date

from analysis.dataset_definition.add_variables import(
    add_inex_variables
)

# Codelists from codelists.py (which pulls all variables from the codelist folder)
from codelists import *
@table_from_file("output/dataset_clean/input_clean_prematch.csv.gz")
class input_inex(PatientFrame):
    qa_num_birth_year = Series(int)


## Create dataset
dataset = create_dataset()

#Get study dates
from analysis.dataset_definition.study_dates import *

#Add region variable for regional analysis
dataset.desc_cat_region = practice_registrations.for_patient_on(start_date).practice_nuts1_region_name

# Gap sizes for sensitivity analyses
gap_sizes = [30, 90, 180]

# Add inex variables for 2015 through 2024
for year in range(2017, 2025):
    #Add collapsed in/ex variable for each year in the study
    add_inex_variables(dataset, date(year, 1, 1), 1,year)
    
    med_rev=(clinical_events.where(clinical_events.snomedct_code.is_in(medication_review_codelist))
        .where(clinical_events.date.is_on_or_after(date(year, 1, 1)))
        .where(clinical_events.date.is_before(date(year, 1, 1)+days(365)))
        .count_for_patient())
    
    med_rev_dat=(clinical_events.where(clinical_events.snomedct_code.is_in(medication_review_codelist))
    .where(clinical_events.date.is_on_or_after(date(year, 1, 1)))
    .where(clinical_events.date.is_before(date(year, 1, 1)+days(365)))
    .sort_by(clinical_events.date)
    .first_for_patient()
    .date)
    
    # Add medication review variables for each year
    dataset.add_column(f"desc_num_med_rev_{year}", med_rev)
    dataset.add_column(f"desc_dat_med_rev_{year}", med_rev_dat)

    # Loop through gap sizes
    for gap_size in gap_sizes:
    
        # Add variables for date of first stop following medication review for each year for each medication class
        get_stopping_dates_after_event(dataset, date(year, 1, 1), date(year, 1, 1)+days(365), ace_inhibitor_codelist, medication_review_codelist, f"desc_dat_stop_acei_{gap_size}_{year}", 10, gap_size)
        get_stopping_dates_after_event(dataset, date(year, 1, 1), date(year, 1, 1)+days(365), alpha_adrenoceptor_blocking_drugs_codelist, medication_review_codelist, f"desc_dat_stop_aab_{gap_size}_{year}", 10, gap_size)
        get_stopping_dates_after_event(dataset, date(year, 1, 1), date(year, 1, 1)+days(365), angiotensin_ii_receptor_blockers_codelist, medication_review_codelist, f"desc_dat_stop_arb_{gap_size}_{year}", 10, gap_size)
        get_stopping_dates_after_event(dataset, date(year, 1, 1), date(year, 1, 1)+days(365), beta_blockers_codelist, medication_review_codelist, f"desc_dat_stop_bb_{gap_size}_{year}", 10, gap_size)
        get_stopping_dates_after_event(dataset, date(year, 1, 1), date(year, 1, 1)+days(365), calcium_channel_blockers_codelist, medication_review_codelist, f"desc_dat_stop_ccb_{gap_size}_{year}", 10, gap_size)
        get_stopping_dates_after_event(dataset, date(year, 1, 1), date(year, 1, 1)+days(365), centrally_acting_antihypertensives_codelist, medication_review_codelist, f"desc_dat_stop_caa_{gap_size}_{year}", 10, gap_size)
        get_stopping_dates_after_event(dataset, date(year, 1, 1), date(year, 1, 1)+days(365), potassium_sparing_diuretics_codelist, medication_review_codelist, f"desc_dat_stop_psd_{gap_size}_{year}", 10, gap_size)


##Define population
dataset.configure_dummy_data()
dataset.define_population(input_inex.exists_for_patient())
