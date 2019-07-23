require_relative "../../../helper"

describe ConceptQL::Operators::Read do
  it "be present in list of operators" do
    ConceptQL::Operators.operators[:omopv4_plus]["read"].must_equal ConceptQL::Operators::Read
  end

  it "should produce correct SQL under omopv4_plus" do
    db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :omopv4_plus)
    db.query(["read", "xyz"]).sql.must_equal "SELECT * FROM (SELECT * FROM (SELECT \"person_id\", \"criterion_id\", \"criterion_table\", \"criterion_domain\", \"start_date\", \"end_date\", \"source_value\", \"source_vocabulary_id\" FROM (SELECT * FROM (SELECT \"person_id\" AS \"person_id\", \"observation_id\" AS \"criterion_id\", CAST('observation' AS text) AS \"criterion_table\", CAST('observation' AS text) AS \"criterion_domain\", CAST(\"observation_date\" AS date) AS \"start_date\", CAST(coalesce(\"observation_date\", \"observation_date\") AS date) AS \"end_date\", CAST(\"observation_source_value\" AS text) AS \"source_value\", CAST(\"observation_source_vocabulary_id\" AS text) AS \"source_vocabulary_id\" FROM \"observation\" AS \"tab\" WHERE ((\"observation_source_value\" IN ('xyz')) AND (\"observation_source_vocabulary_id\" = 17))) AS \"t1\") AS \"t1\") AS \"t1\") AS \"t1\""
  end

  it "should include measurement columns under GDM" do
    db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
    db.query(["read", "xyz"]).operator.required_columns.must_include(:range_high)
  end
end


