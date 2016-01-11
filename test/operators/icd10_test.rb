require_relative '../helper'

describe ConceptQL::Operators::Icd10 do
  it "should produce correct results" do
    criteria_ids(
      icd10: 'Z56.1'
    ).must_equal("condition_occurrence"=>[34546])
  end
end
