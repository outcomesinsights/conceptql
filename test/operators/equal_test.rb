require_relative '../helper'

describe ConceptQL::Operators::Equal do
  it "should produce correct results" do
    criteria_ids(
      [:equal, {:left=>[:numeric, 1], :right=>[:numeric, 1, [:ndc, "12745010902"]]}]
    ).must_equal("person"=>[128])

    criteria_ids(
      [:equal,
       {:left=>[:numeric, 1, [:drug_type_concept, 2]],
        :right=>[:numeric, 1, [:ndc, "12745010902"]]}]
    ).must_equal("drug_exposure"=>[1])
  end
end

