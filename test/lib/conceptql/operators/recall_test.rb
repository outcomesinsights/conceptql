require_relative "../../../helper"

describe ConceptQL::Operators::Recall do
  it "should produce correct SQL under omopv4_plus" do
    db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :omopv4_plus)
    db.query(["recall", "r", label: "r"]).scope_annotate(skip_db: true).must_equal ""
  end
end

