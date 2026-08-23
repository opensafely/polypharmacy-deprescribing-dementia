## This file loads all the necessary codelists for this project from OpenCodelists 
from ehrql import codelist_from_csv

# Ethnicity
ethnicity_snomed = codelist_from_csv(
  "codelists/opensafely-ethnicity-snomed-0removed.csv",
  column = "code",
  category_column = "Grouping_6"
)

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

## Centrally acting antihypertensives codes
centrally_acting_antihypertensives_codelist = codelist_from_csv(
    "codelists/user-robert_porteous-centrally-acting-antihypertensives-dmd.csv",
    column="code"
)

## Potassium sparing diuretics codes
potassium_sparing_diuretics_codelist = codelist_from_csv(
    "codelists/user-robert_porteous-potassium-sparing-diuretics-aldosterone-antagonists-and-compounds-dmd.csv",
    column="code"
)

thiazide_type_diuretics_codelist = codelist_from_csv(
    "codelists/opensafely-thiazide-type-diuretic-medication.csv",
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

# AMI (Acute Myocardial Infarction)
ami_snomed = codelist_from_csv(
  "codelists/user-elsie_horne-ami_snomed.csv",
  column = "code"
)
ami_icd10 = codelist_from_csv(
  "codelists/user-RochelleKnight-ami_icd10.csv",
  column = "code"
)
ami_prior_icd10 = codelist_from_csv(
  "codelists/user-elsie_horne-ami_prior_icd10.csv",
  column = "code"
)

# Stroke Ischaemic (Ischaemic Stroke)
stroke_isch_snomed = codelist_from_csv(
  "codelists/user-elsie_horne-stroke_isch_snomed.csv",
  column = "code"
)
stroke_isch_icd10 = codelist_from_csv(
  "codelists/user-RochelleKnight-stroke_isch_icd10.csv",
  column = "code"
)

# Cancer
cancer_snomed = codelist_from_csv(
  "codelists/user-elsie_horne-cancer_snomed.csv",
  column = "code"
)
cancer_icd10 = codelist_from_csv(
  "codelists/user-elsie_horne-cancer_icd10.csv",
  column = "code"
)

# Hypertension
hypertension_icd10 = codelist_from_csv(
  "codelists/user-elsie_horne-hypertension_icd10.csv",
  column = "code"
)
hypertension_snomed = codelist_from_csv(
  "codelists/nhsd-primary-care-domain-refsets-hyp_cod.csv",
  column = "code"
)

# Smoking
smoking_clear = codelist_from_csv(
  "codelists/opensafely-smoking-clear.csv",
  column = "CTV3Code",
  category_column = "Category"
)
smoking_unclear = codelist_from_csv(
  "codelists/opensafely-smoking-unclear.csv",
  column = "CTV3Code",
  category_column = "Category"
)
ever_current_smoke = codelist_from_csv(
  "codelists/bristol-smoke-and-eversmoke.csv",
  column = "code"
)

#frailty codes
mild_frailty = codelist_from_csv(
  "codelists/nhsd-primary-care-domain-refsets-mildfrailty_cod.csv",
  column = "code"
)
moderate_frailty = codelist_from_csv(
  "codelists/nhsd-primary-care-domain-refsets-modfrailty_cod.csv",
  column = "code"
)
severe_frailty = codelist_from_csv(
  "codelists/nhsd-primary-care-domain-refsets-sevfrailty_cod.csv",
  column = "code"
)
frailty_score = codelist_from_csv(
  "codelists/nhsd-primary-care-domain-refsets-clinfrailscr_cod.csv",
  column = "code"
)




#Codelists for Cambridge multimorbidity score

def create_codelist_dict(dic: dict) -> dict:
    '''
    Create a dictionary of codelists, so that queries can be run iteratively on
    groups of codelists that are subject to the same ehrQL query.
    Args:
        dic: dictionary where key = name, value = codelist csv path
    Returns:
        Dictionary where key = name, value = codelist
    '''
    for name in dic:
        dic[name] = codelist_from_csv(dic[name], 
                                                column = "code")
    return dic

# For multimorbidity groups

# Multimorbidity groups (20 conditions, alphabetical order)
multimorbidity_dict = {
    ## Alcohol Problems
    "MS_AlcoholProblem_snomed": "codelists/bristol-multimorbidity_alcoholproblems.csv",

    ## Anxiety/Depression (medication to be added)
    "MS_AnxietyDepression_snomed": "codelists/bristol-multimorbidity_anxietydepression.csv",
    "MS_AnxietyDepression_dmd": "codelists/user-ZoeMZou-multimorbidity_prescription_anxiolytics_anti_depressants.csv",

    ## Asthma (medication to be added)
    "MS_Asthma_snomed": "codelists/nhsd-primary-care-domain-refsets-ast_cod.csv",
    "MS_Asthma_dmd": "codelists/opensafely-asthma-inhaler-salbutamol-medication.csv",

    ## Atrial Fibrillation
    "MS_AF_snomed": "codelists/bristol-multimorbidity_atrial-fibrillation.csv",

    ## Cancer
    "MS_Cancer_snomed": "codelists/bristol-multimorbidity_cancer.csv",

    ## Chronic Kidney Disease
    "MS_CKD_snomed": "codelists/bristol-multimorbidity_chronic-kidney-disease.csv",

    ## Constipation (medication only)
    "MS_Constipation_dmd": "codelists/user-ZoeMZou-multimorbidity_prescription_chronic_constipation.csv",

    ## Connective Tissue Disorder
    "MS_CTD_snomed": "codelists/bristol-multimorbidity_connective-tissue-disorder.csv",

    ## COPD
    "MS_COPD_snomed": "codelists/bristol-multimorbidity_copd.csv",

    ## Coronary Heart Disease
    "MS_CHD_snomed": "codelists/bristol-multimorbidity_coronary-heart-disease.csv",

    ## Dementia
    "MS_Dementia_snomed": "codelists/bristol-multimorbidity_dementia.csv",

    ## Diabetes Mellitus
    "MS_Diabetes_snomed": "codelists/bristol-multimorbidity_diabetes.csv",

    ## Epilepsy (medication to be added)
    "MS_Epilepsy_snomed": "codelists/bristol-multimorbidity_epilepsy.csv",
    "MS_Epilepsy_dmd": "codelists/user-ZoeMZou-multimorbidity_prescription_epilepsy.csv",

    ## Hearing Loss
    "MS_HL_snomed": "codelists/bristol-multimorbidity_hearing-loss.csv",

    ## Heart Failure
    "MS_HF_snomed": "codelists/bristol-multimorbidity_heart-failure.csv",

    ## Hypertension
    "MS_Hypertension_snomed": "codelists/nhsd-primary-care-domain-refsets-hyp_cod.csv",

    ## Irritable Bowel Syndrome (medication to be added)
    "MS_IBS_snomed": "codelists/bristol-multimorbidity_irritable-bowel-syndrome.csv",
    "MS_IBS_dmd": "codelists/user-ZoeMZou-multimorbidity_prescription_anti_spasmodic.csv",
    
    ## Painful Condition (Osteoarthritis)
    "MS_PC_Analgesics_dmd": "codelists/user-ZoeMZou-multimorbidity_prescription_analgesics_opiods_not_migraine.csv",
    "MS_PC_Antiepileptic_dmd": "codelists/user-ZoeMZou-multimorbidity_prescription_anti_epileptic_for_pain_only.csv",

    ## Psychosis/Bipolar Disorder (medication to be added)
    "MS_Psychosis_snomed": "codelists/bristol-multimorbidity_psychosisbipolar-disorder.csv",
    "MS_Psychosis_dmd": "codelists/user-ZoeMZou-multimorbidity_prescription_schizophrenia_bipolar_disorder.csv",

    ## Stroke/Transient Ischemic Attack (TIA)
    "MS_StrokeTIA_snomed": "codelists/bristol-multimorbidity_stroketransient-ischemic-attack.csv",
}

# Apply helper to load
multimorbidity_dict = create_codelist_dict(multimorbidity_dict)