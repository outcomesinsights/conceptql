require_relative '../helper'

describe ConceptQL::Operators::VisitOccurrence do
  it "should produce correct results" do
    criteria_ids(
      [:visit_occurrence, [:icd9, "412"]]
    ).must_equal("visit_occurrence"=>[757, 802, 1918, 2550, 2705, 3083, 3514, 3749, 3847, 4378, 4497, 4595, 4783, 5715, 6017, 6640, 7484, 7810, 7812, 8108, 8166, 8689, 8806, 8819, 9257, 9540, 9544, 10088, 10115, 10767, 10786, 10887, 10894, 11022, 11148, 11198, 11412, 11416, 11783, 12029, 12370, 12373, 13529, 13783, 13839, 13941, 13972, 14055, 14206, 14443])

    criteria_counts(
      [:visit_occurrence, [:gender, "Male"]]
    ).must_equal("visit_occurrence"=>7562)

    criteria_counts(
      [:visit_occurrence]
    ).must_equal("visit_occurrence"=>14931)
  end

  it "should handle errors when annotating" do
    query(
      [:visit_occurrence, [:icd9, "412"], [:icd9, "412"]]
    ).annotate.must_equal(
      ["visit_occurrence",
       ["icd9", "412", {:annotation=>{:condition_occurrence=>{:rows=>50, :n=>38}}, :name=>"ICD-9 CM"}],
       ["icd9", "412", {:annotation=>{:condition_occurrence=>{:rows=>50, :n=>38}}, :name=>"ICD-9 CM"}],
       {:annotation=>{:errors=>[["has multiple upstreams"]]}}]
    )

    query(
      [:visit_occurrence, 21, [:icd9, "412"]]
    ).annotate.must_equal(
      ["visit_occurrence",
       ["icd9", "412", {:annotation=>{:condition_occurrence=>{:rows=>50, :n=>38}}, :name=>"ICD-9 CM"}],
       21,
       {:annotation=>{:errors=>[["has arguments"]]}}]
    )
  end
end
