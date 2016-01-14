require_relative '../helper'

describe ConceptQL::Operators::DrugTypeConcept do
  it "should produce correct results" do
    criteria_ids(
      [:drug_type_concept, 2]
    ).must_equal("drug_exposure"=>[1])

    criteria_ids(
      [:drug_type_concept, 1]
    ).must_equal({})
  end
end
