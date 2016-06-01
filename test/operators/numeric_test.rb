require_relative '../helper'

describe ConceptQL::Operators::Numeric do
  it "should produce correct results" do
    numeric_values(
      [:numeric, 1]
    ).must_equal("person"=>[1]*250)

    numeric_values(
      [:numeric, 1, [:icd9_procedure, "00.13"]]
    ).must_equal("procedure_occurrence"=>[1])

    numeric_values(
      [:numeric, :criterion_id, [:icd9_procedure, "00.13"]]
    ).must_equal("procedure_occurrence"=>[23854.0])
  end

  it "should handle errors when annotating" do
    query(
      [:numeric, [:icd9, "412"], [:icd9_procedure, "00.13"]]
    ).annotate.must_equal(
      ["numeric",
       ["icd9", "412", {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>55, :n=>42}}}, :name=>"ICD-9 CM"}],
       ["icd9_procedure", "00.13", {:annotation=>{:counts=>{:procedure_occurrence=>{:rows=>1, :n=>1}}}, :name=>"ICD-9 Proc"}],
       {:annotation=>{:counts=>{:procedure_occurrence=>{:rows=>0, :n=>0}, :condition_occurrence=>{:n=>0, :rows=>0}}, :errors=>[["has multiple upstreams"], ["has no arguments"]]}}]
    )
  end
end
