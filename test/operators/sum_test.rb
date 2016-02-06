require_relative '../helper'

describe ConceptQL::Operators::Sum do
  it "should produce correct results" do
    numeric_values(
      [:sum, [:numeric, 1, [:ndc, "12745010902"]]]
    ).must_equal("drug_exposure"=>[1])

    numeric_values(
      [:sum, [:icd9_procedure, "0.13"], [:numeric, 1, [:ndc, "12745010902"]]]
    ).must_equal("drug_exposure"=>[1.0], "procedure_occurrence"=>[nil])

    numeric_values(
      [:sum, [:numeric, 1]]
    ).must_equal("person"=>[1]*250)
  end

  it "should handle errors when annotating" do
    query(
      [:sum]
    ).annotate.must_equal(
      ["sum", {:annotation=>{:errors=>[["has no upstream"]]}}]
    )
  end
end
