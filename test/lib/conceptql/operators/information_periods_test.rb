require_relative "../../../helper"
require "conceptql"

describe ConceptQL::Operators::InformationPeriods do
  it "should appear for both GDM" do
    ConceptQL::Operators.operators[:gdm]["information_periods"].must_equal ConceptQL::Operators::InformationPeriods
  end

  it "should appear for both OMOPv4+" do
    ConceptQL::Operators.operators[:omopv4_plus]["information_periods"].must_equal ConceptQL::Operators::InformationPeriods
  end

  it "should produce correct SQL under gdm" do
    db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
    db.query(["information_periods"]).sql.must_equal "SELECT * FROM (SELECT * FROM (SELECT \"patient_id\" AS \"person_id\", \"id\" AS \"criterion_id\", CAST('information_periods' AS text) AS \"criterion_table\", CAST('observation_period' AS text) AS \"criterion_domain\", \"start_date\", \"end_date\", CAST(NULL AS text) AS \"source_value\", CAST(NULL AS integer) AS \"source_vocabulary_id\" FROM \"information_periods\") AS \"t1\") AS \"t1\""
  end

  it "should produce correct SQL under omopv4_plus" do
    db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :omopv4_plus)
    db.query(["information_periods"]).sql.must_equal "SELECT * FROM (SELECT * FROM (SELECT \"person_id\" AS \"person_id\", \"observation_period_id\" AS \"criterion_id\", CAST('observation_period' AS text) AS \"criterion_table\", CAST('observation_period' AS text) AS \"criterion_domain\", CAST(\"observation_period_start_date\" AS date) AS \"start_date\", CAST(coalesce(\"observation_period_end_date\", \"observation_period_start_date\") AS date) AS \"end_date\", CAST(NULL AS text) AS \"source_value\", CAST(NULL AS integer) AS \"source_vocabulary_id\" FROM \"observation_period\") AS \"t1\") AS \"t1\""
  end
end

