require_relative '../helper'

describe ConceptQL::Operators::Count do
  it "should produce correct results" do
    criteria_ids(
      [:count, [:numeric, 1, [:ndc, "12745010902"]]]
    ).must_equal("drug_exposure"=>[1])

    criteria_ids(
      [:count, [:icd9_procedure, "0.13"], [:numeric, 1, [:ndc, "12745010902"]]]
    ).must_equal("drug_exposure"=>[1], "procedure_occurrence"=>[29154])

    criteria_ids(
      [:count, [:numeric, 1]]
    )["person"].inject(:+).must_equal(35929)
  end
end


