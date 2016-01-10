require_relative '../helper'

describe ConceptQL::Operators::Loinc do
  it "should produce correct results" do
    criteria_ids(
      loinc: '13298-5'
    ).must_equal("observation"=>[2])
  end
end
