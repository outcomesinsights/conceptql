require_relative '../helper'

describe ConceptQL::Operators::Sum do
  it "should produce correct results" do
    numeric_values(
      [:sum, [:numeric, 1, [:ndc, "12745010902"]]]
    ).must_equal("drug_exposure"=>[1])

    numeric_values(
      [:sum, [:icd9_procedure, "00.13"], [:numeric, 1, [:ndc, "12745010902"]]]
    ).must_equal("drug_exposure"=>[1.0], "procedure_occurrence"=>[nil])

    numeric_values(
      [:sum, [:numeric, 1]]
    ).must_equal("person"=>[1]*250)
  end

  it "should handle errors when annotating" do
    query(
      [:sum]
    ).annotate.must_equal(
      ["sum", {:annotation=>{:counts=>{:invalid=>{:rows=>0, :n=>0}},:errors=>[["has no upstream"]]}}]
    )

    query(
      [:sum, 21, [:numeric, 1]]
    ).annotate.must_equal(
      ["sum",
       ["numeric", 1, {:annotation=>{:counts=>{:person=>{:rows=>250, :n=>250}}}}],
       21,
       {:annotation=>{:counts=>{:person=>{:rows=>0, :n=>0}}, :errors=>[["has arguments"]]}}]
    )
  end
end
