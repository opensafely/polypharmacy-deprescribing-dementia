from ehrql.tables.tpp import practice_registrations, clinical_events
from ehrql import create_dataset, days
from ehrql.query_language import table_from_file , PatientFrame, Series
from datetime import date

from analysis.dataset_definition.add_variables import(
    add_inex_variables
)

# Codelists from codelists.py (which pulls all variables from the codelist folder)
from codelists import *
@table_from_file("output/dataset_clean/input_clean_prematch.parquet")
class input_inex(PatientFrame):
    qa_num_birth_year = Series(str)


## Create dataset
dataset = create_dataset()

#Get study dates
from analysis.dataset_definition.study_dates import *

#Add region variable for regional analysis
dataset.desc_cat_region = practice_registrations.for_patient_on(start_date).practice_nuts1_region_name

## Add inex variables for 2015 through 2024
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



##Define population
dataset.configure_dummy_data()
dataset.define_population(input_inex.exists_for_patient())
