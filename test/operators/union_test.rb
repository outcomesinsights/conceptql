require_relative '../helper'

describe ConceptQL::Operators::Union do
  it "should produce correct results" do
    criteria_counts(
      union: [
        { icd9: '412' },
        { icd9: '401.9' }
      ]
    ).must_equal("condition_occurrence"=>1175)

    criteria_counts(
      union: [
        {union: [
          { icd9: '412' },
          { icd9: '401.9' }
        ]},
        { place_of_service_code: '21' }
      ]
    ).must_equal("condition_occurrence"=>1175, "visit_occurrence"=>170)
  end
end

