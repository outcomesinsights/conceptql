require_relative 'db'

if DB.opts[:database] && DB.opts[:database] !~ /test/
  $stderr.puts <<END
The test database name doesn't include the substring "test".
Exiting now to avoid potential modification of non-test database.
Please rename your test database to include the substring "test".
END
  exit 1
end

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
