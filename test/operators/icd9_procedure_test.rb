require_relative '../helper'

describe ConceptQL::Operators::Icd9Procedure do
  it "should produce correct results" do
    criteria_ids(
      [:icd9_procedure, '00.13']
    ).must_equal("procedure_occurrence"=>[23854])
  end
end
