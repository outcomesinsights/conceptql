require_relative "../../../helper"
require "conceptql"

describe ConceptQL::Operators::Selection::Vocabulary do
  it "should include measurement columns under GDM" do
    db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
    _(db.query(["read", "xyz"]).operator.output_columns).must_include(:range_high)
  end
end


