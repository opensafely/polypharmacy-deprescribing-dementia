from ehrql import create_dataset, codelist_from_csv
from ehrql.tables.tpp import patients, practice_registrations, clinical_events, addresses

##Create dataset
dataset = create_dataset()

##Set start date
index_date = "2015-01-01"
end_date = "2015-12-31"
##Create codelist objects
dementia_codelist = codelist_from_csv(
    #Need to decide which codelist to use "codelists/bristol-any-dementia-snomed-ct-v14.csv", 
    "codelists/nhsd-primary-care-domain-refsets-dem_cod.csv",
    column="code"
)

##Derive dataset variables
dataset.sex = patients.sex
dataset.age = patients.age_on(index_date)
dataset.latest_dementia_code = (
    clinical_events.where(clinical_events.snomedct_code.is_in(dementia_codelist))
    .where(clinical_events.date.is_on_or_before(end_date))
    .sort_by(clinical_events.date)
    .last_for_patient()
    .snomedct_code)
dataset.imd = addresses.for_patient_on(index_date).imd_rounded
dataset.region = practice_registrations.for_patient_on(index_date).practice_nuts1_region_name

##Apply study population criteria from protocol
aged_65_or_above = dataset.age > 64
has_registration = practice_registrations.for_patient_on(index_date).exists_for_patient()

has_dementia = (
    clinical_events.where(clinical_events.snomedct_code.is_in(dementia_codelist))
    .where(clinical_events.date.is_on_or_before(end_date))
    .sort_by(clinical_events.date)
    .last_for_patient()
    ).exists_for_patient()

is_alive = patients.is_alive_on(index_date)
known_sex = patients.sex != "unknown"
known_imd = (dataset.imd >= 0)
known_region = dataset.region != ""

##Define population
dataset.define_population(has_registration & has_dementia & aged_65_or_above & is_alive & known_sex & known_imd & known_region)
dataset.configure_dummy_data(population_size=100)