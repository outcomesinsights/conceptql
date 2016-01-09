require_relative 'db'

tables = [
  :care_site,
  :cohort,
  :location,
  :provider,
  :organization,
  :person,
  :condition_era,
  :condition_occurrence,
  :death,
  :drug_era,
  :drug_exposure,
  :observation,
  :observation_period,
  :payer_plan_period,
  :procedure_occurrence,
  :visit_occurrence,
  :drug_cost,
  :procedure_cost
]

DB.drop_table?(*tables.reverse)
