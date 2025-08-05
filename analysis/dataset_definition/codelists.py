## This file loads all the necessary codelists for this project from OpenCodelists 
from ehrql import codelist_from_csv

## All dementia codes 
dementia_codelist = codelist_from_csv(
    "codelists/nhsd-primary-care-domain-refsets-dem_cod.csv",
    column="code"
)
## Vascular dementia codes
vascular_dementia_codelist = codelist_from_csv(
    "codelists/nhsd-primary-care-domain-refsets-vascular-dementia-codes.csv",
    column="code"
)
## Alzheimer's codes
alzheimers_codelist = codelist_from_csv(
    "codelists/nhsd-primary-care-domain-refsets-alzheimers-disease-dementia-codes.csv",
    column="code"
)
# Other dementia = codes in general list but not in alz or vasc
other_dementia_codelist = list(
    set(dementia_codelist) - set(alzheimers_codelist).union(vascular_dementia_codelist)
)
## Antihypertensive codes
antihypertensive_codelist = codelist_from_csv(
    "codelists/opensafely-combination-blood-pressure-medication.csv",
    column="code"
)

## Medication review codes
medication_review_codelist = codelist_from_csv(
    "codelists/nhsd-primary-care-domain-refsets-demmedrvw_cod.csv",
    column="code"
)




## Covariates
## Will put more codelists here
## etc etc
