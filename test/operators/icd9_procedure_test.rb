require_relative '../helper'

describe ConceptQL::Operators::Icd9Procedure do
  it "should produce correct results" do
    criteria_ids("icd9_procedure/crit_1",
      [:icd9_procedure, '00.13']
    )
  end
end
