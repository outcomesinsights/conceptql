require_relative "../../../helper"

describe ConceptQL::Operators::Read do
  it "be present in list of operators" do
    ConceptQL::Operators.operators[:omopv4_plus]["read"].must_equal ConceptQL::Operators::Read
  end

  it "should produce correct SQL under omopv4_plus" do
    db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :omopv4_plus)
    db.query(["read", "xyz"]).sql.must_match %Q{"observation_source_vocabulary_id" = 17}
    db.query(["read", "xyz"]).sql.must_match %Q{"observation_source_value" IN ('xyz')}
  end

  it "should include measurement columns under GDM" do
    db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
    db.query(["read", "xyz"]).operator.required_columns.must_include(:range_high)
  end
end


