from ehrql.tables.tpp import patients, practice_registrations, clinical_events, addresses, medications, ons_deaths, apcs, decision_support_values, emergency_care_attendances
from ehrql import create_dataset, codelist_from_csv, days, case, when, minimum_of, show
from datetime import date
from analysis.dataset_definition.variable_helper_functions import (
    get_prescription_dates, 
    get_prescription_gaps,
    last_matching_event_clinical_snomed_before,
    last_matching_event_apc_before,
    last_matching_event_clinical_ctv3_before,
    ever_matching_event_clinical_ctv3_before,
    filter_codes_by_category
)

# Codelists from codelists.py (which pulls all variables from the codelist folder)
from codelists import *

## Create function to add all variables for inclusion and exclusion criteria.
def add_inex_variables(dataset, start_date):
    
    # Dementia diagnosis
    inex_bin_has_dem = (
        clinical_events.where(clinical_events.snomedct_code.is_in(dementia_codelist))
        .where(clinical_events.date.is_on_or_before(start_date))
        ).exists_for_patient()

    # Long-term antihypertensive user 
    inex_bin_antihyp = ((medications.where(medications.dmd_code.is_in(ace_inhibitor_codelist))
        .where(medications.date.is_on_or_after(start_date - days(365)))
        .where(medications.date.is_on_or_before(start_date))
        .count_for_patient()) > 2) | ((medications.where(medications.dmd_code.is_in(alpha_adrenoceptor_blocking_drugs_codelist))
        .where(medications.date.is_on_or_after(start_date - days(365)))
        .where(medications.date.is_on_or_before(start_date))
        .count_for_patient()) > 2) | ((medications.where(medications.dmd_code.is_in(angiotensin_ii_receptor_blockers_codelist))
        .where(medications.date.is_on_or_after(start_date - days(365)))
        .where(medications.date.is_on_or_before(start_date))
        .count_for_patient()) > 2) | ((medications.where(medications.dmd_code.is_in(beta_blockers_codelist))
        .where(medications.date.is_on_or_after(start_date - days(365)))
        .where(medications.date.is_on_or_before(start_date))
        .count_for_patient()) > 2) | ((medications.where(medications.dmd_code.is_in(calcium_channel_blockers_codelist))
        .where(medications.date.is_on_or_after(start_date - days(365)))
        .where(medications.date.is_on_or_before(start_date))
        .count_for_patient()) > 2) | ((medications.where(medications.dmd_code.is_in(centrally_acting_antihypertensives_codelist))
        .where(medications.date.is_on_or_after(start_date - days(365)))
        .where(medications.date.is_on_or_before(start_date))
        .count_for_patient()) > 2)

    # Alive at start date
    inex_bin_alive = (((patients.date_of_death.is_null()) | (patients.date_of_death.is_after(start_date))) & 
        ((ons_deaths.date.is_null()) | (ons_deaths.date.is_after(start_date))))

    #65 or over at start date
    inex_bin_over_64 = patients.age_on(start_date)>64

    # Registered with practice at within 6 months of start date
    inex_bin_6m_reg = (practice_registrations.spanning(
            start_date - days(180), start_date
            )).exists_for_patient()

    #Known sex
    inex_bin_known_sex = (patients.sex == "male") | (patients.sex == "female")
    #Known IMD
    inex_bin_known_imd = addresses.for_patient_on(start_date).imd_rounded.is_not_null()
    #Known region
    inex_bin_known_region = practice_registrations.for_patient_on(start_date).practice_nuts1_region_name.is_not_null()


    #Add all variables to the dataset
    inex_vars = {name: value for name, value in locals().items() if name.startswith("inex_")}

    # Add them all to the dataset
    for name, expr in inex_vars.items():
        dataset.add_column(name, expr)


def add_covariates(dataset, index_date, end_date):

    cov_num_age = patients.age_on(index_date)
    cov_cat_sex = patients.sex

    ### Ethnicity
    tmp_cov_cat_ethnicity = (
        clinical_events.where(clinical_events.snomedct_code.is_in(ethnicity_snomed))
        .sort_by(clinical_events.date)
        .last_for_patient()
        .snomedct_code
    )
    
    cov_cat_ethnicity = tmp_cov_cat_ethnicity.to_category(ethnicity_snomed)

    ### Deprivation
    cov_cat_imd = case(
            when((addresses.for_patient_on(index_date).imd_rounded >= 0) & 
                    (addresses.for_patient_on(index_date).imd_rounded < int(32844 * 1 / 5))).then("1 (most deprived)"),
            when(addresses.for_patient_on(index_date).imd_rounded < int(32844 * 2 / 5)).then("2"),
            when(addresses.for_patient_on(index_date).imd_rounded < int(32844 * 3 / 5)).then("3"),
            when(addresses.for_patient_on(index_date).imd_rounded < int(32844 * 4 / 5)).then("4"),
            when(addresses.for_patient_on(index_date).imd_rounded < int(32844 * 5 / 5)).then("5 (least deprived)"),
            otherwise="unknown",
        )

    cov_cat_region = practice_registrations.for_patient_on(index_date).practice_nuts1_region_name

    # Date of first dementia diagnosis
    cov_dat_dem = (
        clinical_events.where(clinical_events.snomedct_code.is_in(dementia_codelist))
        .where(clinical_events.date.is_on_or_before(end_date))
        .sort_by(clinical_events.date)
        .first_for_patient()
        .date)

    # Alzheimer's diagnosis
    cov_bin_dem_alz = (
        clinical_events.where(clinical_events.snomedct_code.is_in(alzheimers_codelist))
        .where(clinical_events.date.is_on_or_before(end_date))
        ).exists_for_patient()

    # Vascular dementia diagnosis
    cov_bin_dem_vasc = (
        clinical_events.where(clinical_events.snomedct_code.is_in(vascular_dementia_codelist))
        .where(clinical_events.date.is_on_or_before(end_date))
        ).exists_for_patient()

    # "Other" dementia diagnosis
    cov_bin_dem_other = (
        clinical_events.where(clinical_events.snomedct_code.is_in(other_dementia_codelist))
        .where(clinical_events.date.is_on_or_before(end_date))
        ).exists_for_patient()

    # Acute MI diagnosis
    cov_bin_ami = (
            (last_matching_event_clinical_snomed_before(
                ami_snomed, index_date
            ).exists_for_patient()) |
            (last_matching_event_apc_before(
                ami_icd10 + ami_prior_icd10, index_date
            ).exists_for_patient())
        )

    ### Ischaemic stroke
    cov_bin_stroke = (
        (last_matching_event_clinical_snomed_before(
            stroke_isch_snomed, index_date
        ).exists_for_patient()) |
        (last_matching_event_apc_before(
            stroke_isch_icd10, index_date
        ).exists_for_patient())
    )

    #Date of CHD diagnosis
    cov_dat_chd = (
        clinical_events.where(clinical_events.snomedct_code.is_in(chd_codelist))
        .where(clinical_events.date.is_on_or_before(end_date))
        .sort_by(clinical_events.date)
        .first_for_patient()
        .date)

    ### Cancer
    cov_bin_cancer = (
        (last_matching_event_clinical_snomed_before(
            cancer_snomed, index_date
        ).exists_for_patient()) |
        (last_matching_event_apc_before(
            cancer_icd10, index_date
        ).exists_for_patient())
    )

    ### Hypertension 
    cov_bin_hypertension = (
        (last_matching_event_clinical_snomed_before(
            hypertension_snomed, index_date
        ).exists_for_patient()) |
        (last_matching_event_apc_before(
            hypertension_icd10, index_date
        ).exists_for_patient())
    )

    # Care home status
    cov_bin_carehome = (
            addresses.for_patient_on(index_date).care_home_is_potential_match |
            addresses.for_patient_on(index_date).care_home_requires_nursing |
            addresses.for_patient_on(index_date).care_home_does_not_require_nursing
        )

    ### Smoking status
    tmp_most_recent_smoking_cat = (
        last_matching_event_clinical_ctv3_before(smoking_clear, index_date)
        .ctv3_code.to_category(smoking_clear)
    )
    tmp_ever_smoked = ever_matching_event_clinical_ctv3_before(
        (filter_codes_by_category(smoking_clear, include=["S", "E"])), index_date
        ).exists_for_patient()

    cov_cat_smoking = case(
        when(tmp_most_recent_smoking_cat == "S").then("S"),
        when((tmp_most_recent_smoking_cat == "E") | ((tmp_most_recent_smoking_cat == "N") & (tmp_ever_smoked == True))).then("E"),
        when((tmp_most_recent_smoking_cat == "N") & (tmp_ever_smoked == False)).then("N"),
        otherwise="M"
    )

    # Number of different medications prescribed in the year prior to index date
    cov_num_med_count = ( 
        medications.where(medications.date.is_on_or_before(index_date))
        .where(medications.date.is_after(index_date - days(365)))
        .dmd_code 
        .count_distinct_for_patient())

    # Latest hospitalisation date
    cov_dat_hosp = (
        apcs.where(apcs.admission_date.is_on_or_before(index_date))
        .sort_by(apcs.admission_date)
        .last_for_patient()
        .admission_date
    )

    # Latest A&E attendance
    cov_dat_AE = (
        emergency_care_attendances.where(emergency_care_attendances.arrival_date.is_on_or_before(index_date))
        .sort_by(emergency_care_attendances.arrival_date)
        .last_for_patient()
        .arrival_date
    ) 

    # Frailty score
    latest_efi_record = (
    decision_support_values
        .where(decision_support_values.calculation_date.is_on_or_before(index_date))
        .electronic_frailty_index()
        .sort_by(decision_support_values.calculation_date)
        .last_for_patient()
    )
    cov_num_latest_efi = latest_efi_record.numeric_value
    cov_dat_latest_efi = latest_efi_record.calculation_date
    
    # ---- Add all covariates to dataset ----
    covariates = {name: value for name, value in locals().items() if name.startswith("cov_")}

    for name, expr in covariates.items():
        dataset.add_column(name, expr)
    

#This function adds columns for the next and previous prescriptions of a given medication around an index date
#It also creates the columns counting the frequency of size gaps for the medication within the study period.
def add_out_variables(dataset, index_date, start_date, end_date, medication_codelist, column_suffix):
    ## Date of next antihypertensive medication after medication review
    out_dat_next_med = (
        medications.where(medications.dmd_code.is_in(medication_codelist))
        .where(medications.date.is_after(index_date))
        .where(medications.date.is_on_or_before(end_date))
        .sort_by(medications.date)
        .first_for_patient()
        .date)

    ## Date of previous antihypertensive medication before medication review
    out_dat_prev_med = (
        medications.where(medications.dmd_code.is_in(medication_codelist))
        .where(medications.date.is_before(index_date))
        .where(medications.date.is_on_or_after(start_date))
        .sort_by(medications.date)
        .last_for_patient()
        .date)


    ## Number of days between prescription dates of antihypertensives
    get_prescription_gaps(dataset, start_date, end_date, medication_codelist, column_suffix, 100)

    # ---- Add variables to dataset ----
    dataset.add_column(f"out_dat_next_{column_suffix}", out_dat_next_med)
    dataset.add_column(f"out_dat_prev_{column_suffix}", out_dat_prev_med)
