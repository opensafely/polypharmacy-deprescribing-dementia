from ehrql.tables.tpp import patients, practice_registrations, clinical_events, addresses, medications, ons_deaths, apcs, decision_support_values, emergency_care_attendances
from ehrql import days, case, when, minimum_of
from analysis.dataset_definition.variable_helper_functions import (
    last_matching_event_clinical_snomed_before,
    first_matching_event_clinical_snomed_on_or_before,
    last_matching_event_apc_before,
    last_matching_event_clinical_ctv3_before,
    ever_matching_event_clinical_ctv3_before,
    get_latest_ethnicity,
    get_imd,
    filter_codes_by_category,
    get_cms_on_date,
    any_of
)

# Codelists from codelists.py (which pulls all variables from the codelist folder)
from codelists import *

## Antihypertensive classes used for the eligibility criterion, stopping dates and prescription gaps:
## abbreviation used in column names -> codelist
antihypertensive_class_codelists = {
    "acei": ace_inhibitor_codelist,
    "aab": alpha_adrenoceptor_blocking_drugs_codelist,
    "arb": angiotensin_ii_receptor_blockers_codelist,
    "bb": beta_blockers_codelist,
    "ccb": calcium_channel_blockers_codelist,
    "caa": centrally_acting_antihypertensives_codelist,
    "psd": potassium_sparing_diuretics_codelist,
    "ttd": thiazide_type_diuretics_codelist,
}

## Minimum number of prescriptions of the same antihypertensive class in the year before the start date
MIN_ANTIHYP_PRESCRIPTIONS = 3

## This function returns the inclusion and exclusion criteria for the study on a given date,
## as a dict of {variable name: ehrQL boolean expression}.
## Inputs:
## start_date - the date on which eligibility is assessed (1 January of each study year)
def get_inex_conditions(start_date):

    # Dementia diagnosis
    inex_bin_has_dem = (
        clinical_events.where(clinical_events.snomedct_code.is_in(dementia_codelist))
        .where(clinical_events.date.is_on_or_before(start_date))
        ).exists_for_patient()

    # Long-term antihypertensive user: at least MIN_ANTIHYP_PRESCRIPTIONS prescriptions
    # of the same class in the year before the start date
    inex_bin_antihyp = any_of([
        medications.where(medications.dmd_code.is_in(codelist))
        .where(medications.date.is_on_or_after(start_date - days(365)))
        .where(medications.date.is_on_or_before(start_date))
        .count_for_patient() >= MIN_ANTIHYP_PRESCRIPTIONS
        for codelist in antihypertensive_class_codelists.values()
    ])

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

    return {
        name: value
        for name, value in locals().items() if name.startswith("inex_")
    }

## This function adds each inclusion and exclusion criterion on the given date to the dataset
## as a separate column, so the cleaning step can apply them one at a time for the flow chart.
## dataset - the ehrQL dataset which the variables will be added to
## start_date - the date on which eligibility is assessed (1 January of each study year)
def add_inex_variables(dataset, start_date):
    for name, expr in get_inex_conditions(start_date).items():
        dataset.add_column(name, expr)

## This function adds all the covariates for the study.
## Inputs:
## dataset - the ehrQL dataset which the variables will be added to
## index_date - the start date for which the variables will be calculated and date for non time-varying variables
## end_date - the end date of the period, used to calculate some variables such diagnoses
def add_covariates(dataset, index_date, end_date):

    cov_num_age = patients.age_on(index_date)
    cov_cat_sex = patients.sex

    ### Ethnicity
    cov_cat_ethnicity = get_latest_ethnicity(index_date,ethnicity_snomed, grouping=6)

    ### Deprivation
    cov_cat_imd = get_imd(index_date, groups=5, max_imd=32844)

    cov_cat_region = practice_registrations.for_patient_on(index_date).practice_nuts1_region_name

    # Date of first dementia diagnosis
    cov_dat_dem = first_matching_event_clinical_snomed_on_or_before(dementia_codelist, end_date).date

    # Date of first Alzheimer's diagnosis
    cov_dat_dem_alz = first_matching_event_clinical_snomed_on_or_before(alzheimers_codelist, end_date).date

    # Date of first vascular dementia diagnosis
    cov_dat_dem_vasc = first_matching_event_clinical_snomed_on_or_before(vascular_dementia_codelist, end_date).date

    # Date of first "other" dementia diagnosis
    cov_dat_dem_other = first_matching_event_clinical_snomed_on_or_before(other_dementia_codelist, end_date).date

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
    cov_dat_chd = first_matching_event_clinical_snomed_on_or_before(chd_codelist, end_date).date

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

    # Cambridge multimorbidity score on the index date
    death_date = minimum_of(patients.date_of_death, ons_deaths.date)
    cov_num_cms = get_cms_on_date(index_date, death_date, return_components=False)

    # ---- Add all covariates to dataset ----
    covariates = {name: value for name, value in locals().items() if name.startswith("cov_")}

    for name, expr in covariates.items():
        dataset.add_column(name, expr)


## This function adds the dates of the latest frailty codes (mild, moderate, severe, score) before the index date.
## I'm not currently calling this. WIll be added in a later push, when I fully decide how to use the codes.
def add_frailty_variables(dataset, index_date):

    cov_dat_mildfrail = last_matching_event_clinical_snomed_before(mild_frailty,index_date).date
    cov_dat_moderatefrail = last_matching_event_clinical_snomed_before(moderate_frailty,index_date).date
    cov_dat_severefrail = last_matching_event_clinical_snomed_before(severe_frailty,index_date).date
    cov_dat_scorefrail = last_matching_event_clinical_snomed_before(frailty_score,index_date).date

    cov_num_scorefrail = last_matching_event_clinical_snomed_before(frailty_score,index_date).numeric_value


    # ---- Add variables to dataset ----
    dataset.add_column("cov_dat_mildfrail", cov_dat_mildfrail)
    dataset.add_column("cov_dat_moderatefrail", cov_dat_moderatefrail)
    dataset.add_column("cov_dat_severefrail", cov_dat_severefrail)
    dataset.add_column("cov_dat_scorefrail", cov_dat_scorefrail)
    dataset.add_column("cov_num_scorefrail", cov_num_scorefrail)
