## This script defines the inclusion / exclusion criteria and quality assurance variables
## for one study year. Each criterion is assessed on 1 January of that year and added as a
## separate column, so the cleaning step can apply them one at a time and produce a flow
## chart for each year.
## This code is run once per study yuear as separate actions in the yaml

from ehrql.tables.tpp import patients
from ehrql import create_dataset, get_parameter
from datetime import date

from analysis.dataset_definition.add_variables import add_inex_variables

from codelists import *

## Study year for this dataset
year = get_parameter(name="year", type=int)
index_date = date(year, 1, 1)

## Create dataset
dataset = create_dataset()

## Create variables for inclusion / exclusion criteria on 1 January of the study year
add_inex_variables(dataset, index_date)

## Create variables for data quality checks
dataset.qa_num_birth_year = patients.date_of_birth.year
dataset.qa_num_death_year = patients.date_of_death.year

##Define population
dataset.configure_dummy_data()
dataset.define_population(patients.date_of_birth.is_not_null())
