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

## Medication review codes
medication_review_codelist = codelist_from_csv(
    "codelists/nhsd-primary-care-domain-refsets-demmedrvw_cod.csv",
    column="code"
)

## Antihypertensive codes
antihypertensive_codelist = codelist_from_csv(
    "codelists/opensafely-combination-blood-pressure-medication.csv",
    column="code"
)
## ACE-Inhibitor codes
ace_inhibitor_codelist = codelist_from_csv(
    "codelists/opensafely-ace-inhibitor-medications.csv",
    column="code"
)
## Alpha-Adrenoceptor Blocking Drugs codes
alpha_adrenoceptor_blocking_drugs_codelist = codelist_from_csv(
    "codelists/opensafely-alpha-adrenoceptor-blocking-drugs.csv",
    column="code"
)
## Angiotensin II Receptor Blockers (ARBs) codes
angiotensin_ii_receptor_blockers_codelist = codelist_from_csv(
    "codelists/opensafely-angiotensin-ii-receptor-blockers-arbs.csv",
    column="code"
)
## Beta blockers codes
beta_blockers_codelist = codelist_from_csv(
    "codelists/opensafely-beta-blocker-medications.csv",
    column="code"
)
## Calcium channel blockers codes
calcium_channel_blockers_codelist = codelist_from_csv(
    "codelists/opensafely-calcium-channel-blockers.csv",
    column="code"
)

## Chronic Heart Disease codes
chd_codelist = codelist_from_csv(
    "codelists/primis-covid19-vacc-uptake-chd_cov.csv",
    column="code"
)

## Myocardial Infarction codes
mi_codelist = codelist_from_csv(
    "codelists/nhsd-primary-care-domain-refsets-mi_cod.csv",
    column="code"
)

## Stroke codes
strk_codelist = codelist_from_csv(
    "codelists/nhsd-primary-care-domain-refsets-strk_cod.csv",
    column="code"
)