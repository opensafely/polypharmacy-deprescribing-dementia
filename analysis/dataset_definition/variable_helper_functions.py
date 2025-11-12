from ehrql.tables.tpp import patients, practice_registrations, clinical_events, addresses, ethnicity_from_sus, medications, ons_deaths, apcs
from ehrql import create_dataset, codelist_from_csv, days, case, when, minimum_of, show


## This function creates a column for each prescription date of a medication from a given codelist
## codelist: list of codes to search for
## start_date: date to start searching from
## end_date: date to stop searching
## limit: number of prescription dates to extract
## dataset: dataset to add the columns to
def get_prescription_dates(codelist, start_date, end_date, limit, dataset):
    prev_ah_date = start_date
    for i in range(limit):
        ah_date = (medications.where(medications.dmd_code.is_in(codelist))
        .where(medications.date.is_after(prev_ah_date))
        .where(medications.date.is_on_or_before(end_date))
        .sort_by(medications.date)
        .first_for_patient()
        .date)
        dataset.add_column(f"out_dat_ah_pres_{i}", ah_date)
        prev_ah_date = ah_date


## This function counts the frequency of gaps between prescriptions within specified time intervals
## codelist: list of codes to search for
## start_date: date to start searching from
## end_date: date to stop searching
## limit: number of prescription dates to consider
## dataset: dataset to add the columns to
def get_prescription_gaps(codelist, start_date,end_date, limit, dataset):
    prev_date = start_date
    cnt_0_14 = 0
    cnt_14_30 = 0
    cnt_30_60 = 0
    cnt_60_90 = 0
    cnt_90_180 = 0
    cnt_180_365 = 0
    cnt_365_plus = 0

    for i in range (limit):
        presc_date = (medications.where(medications.dmd_code.is_in(codelist))
        .where(medications.date.is_after(prev_date))
        .where(medications.date.is_on_or_before(end_date))
        .sort_by(medications.date)
        .first_for_patient()
        .date)

        # Don't calculate gap from start date to first prescription
        if i>0:
            diff_days = (presc_date - prev_date).days

            cnt_0_14 += when(diff_days < 14).then(1).otherwise(0)
            cnt_14_30 += when((diff_days >= 14) & (diff_days < 30)).then(1).otherwise(0)
            cnt_30_60 += when((diff_days >= 30) & (diff_days < 60)).then(1).otherwise(0)
            cnt_60_90 += when((diff_days >= 60) & (diff_days < 90)).then(1).otherwise(0)
            cnt_90_180 += when((diff_days >= 90) & (diff_days < 180)).then(1).otherwise(0)
            cnt_180_365 += when((diff_days >= 180) & (diff_days < 365)).then(1).otherwise(0)
            cnt_365_plus += when(diff_days >= 365).then(1).otherwise(0)
        prev_date = presc_date

    dataset.add_column("out_cnt_gap_0_14", cnt_0_14)
    dataset.add_column("out_cnt_gap_14_30", cnt_14_30)
    dataset.add_column("out_cnt_gap_30_60", cnt_30_60)
    dataset.add_column("out_cnt_gap_60_90", cnt_60_90)
    dataset.add_column("out_cnt_gap_90_180", cnt_90_180)
    dataset.add_column("out_cnt_gap_180_365", cnt_180_365)
    dataset.add_column("out_cnt_gap_365_plus", cnt_365_plus)

## Helper function to get the last matching clinical event before a given date
def last_matching_event_clinical_snomed_before(codelist, start_date, where=True):
    return(
        clinical_events.where(where)
        .where(clinical_events.snomedct_code.is_in(codelist))
        .where(clinical_events.date.is_before(start_date))
        .sort_by(clinical_events.date)
        .last_for_patient()
    )

## Helper function to get the last matching APC admission before a given date
def last_matching_event_apc_before(codelist, start_date, only_prim_diagnoses=False, where=True):
    query = apcs.where(where).where(apcs.admission_date.is_before(start_date))
    if only_prim_diagnoses:
        query = query.where(
            apcs.primary_diagnosis.is_in(codelist)
        )
    else:
        query = query.where(apcs.all_diagnoses.contains_any_of(codelist))
    return query.sort_by(apcs.admission_date).last_for_patient()

## Helper function to get most recent matching clinical event before a given date 
def last_matching_event_clinical_ctv3_before(codelist, start_date, where=True):
    return(
        clinical_events.where(where)
        .where(clinical_events.ctv3_code.is_in(codelist))
        .where(clinical_events.date.is_before(start_date))
        .sort_by(clinical_events.date)
        .last_for_patient()
    )

## Helper function to get any matching clinical event before a given date
def ever_matching_event_clinical_ctv3_before(codelist, start_date, where=True):
    return(
        clinical_events.where(where)
        .where(clinical_events.ctv3_code.is_in(codelist))
        .where(clinical_events.date.is_before(start_date))
    )

# filter a codelist based on whether its values included a specified set of allowed values (include)
def filter_codes_by_category(codelist, include):
    return {k:v for k,v in codelist.items() if v in include}