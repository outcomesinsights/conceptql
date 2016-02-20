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

  it "should handle errors when annotating" do
    query(
      [:drug_type_concept, 2, [:icd9, "412"]]
    ).annotate.must_equal(
      ["drug_type_concept",
       ["icd9", "412", {:annotation=>{:condition_occurrence=>{:rows=>50, :n=>38}}, :name=>"ICD-9 CM"}],
       2,
       {:annotation=>{:errors=>[["has upstreams"]]}}]
    )

    query(
      [:drug_type_concept]
    ).annotate.must_equal(
      ["drug_type_concept", {:annotation=>{:errors=>[["has no arguments"]]}}]
    )
  end
end
