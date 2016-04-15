require_relative '../helper'

describe ConceptQL::Operators::Read do
  it "should produce correct results" do
    criteria_ids(
      [:read, "283Z.00"]
    ).must_equal({})
  end

  it "should handle errors when annotating" do
    query(
      [:read, 'XYS']
    ).annotate.must_equal(
      ["read", "XYS", {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>0, :n=>0}}, :warnings=>[["invalid source code", "XYS"]]}, :name=>"READ"}]
    )
  end
end
