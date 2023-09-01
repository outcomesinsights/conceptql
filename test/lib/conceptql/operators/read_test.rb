require_relative "../../../helper"

describe ConceptQL::Operators::Read do
  it "be present in list of operators" do
    _(ConceptQL::Operators.operators[:omopv4_plus]["read"]).must_equal ConceptQL::Operators::Read
  end

  it "should include measurement columns under GDM" do
    db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
    _(db.query(["read", "xyz"]).operator.required_columns).must_include(:range_high)
  end
end
