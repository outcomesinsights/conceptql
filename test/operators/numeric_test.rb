require_relative '../helper'

describe ConceptQL::Operators::Numeric do
  it "should produce correct results" do
    vals = numeric_values(
      numeric: 1
    ).must_equal("person"=>[1]*250)

    numeric_values(
      numeric: [{icd9_procedure: '0.13'}, 1]
    ).must_equal("procedure_occurrence"=>[1])

    numeric_values(
      numeric: [{icd9_procedure: '0.13'}, :criterion_id]
    ).must_equal("procedure_occurrence"=>[29154])
  end
end
