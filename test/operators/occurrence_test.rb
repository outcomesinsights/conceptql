require_relative '../helper'

describe ConceptQL::Operators::Occurrence do
  it "should produce correct results" do
    criteria_ids(
      occurrence: [
        { icd9: '412' },
        2
      ]
    ).must_equal("condition_occurrence"=>[1829, 10196, 17774, 20005, 21619, 24437, 24707, 25309, 25888, 28188, 31542, 31877])
  end
end
