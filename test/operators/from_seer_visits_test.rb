require_relative '../helper'

describe ConceptQL::Operators::FromSeerVisits do
  it "should produce correct results" do
    criteria_ids(
      from_seer_visits: {visit_occurrence: { icd9: '412' }}
    ).must_equal("observation"=>[1, 2])

    criteria_ids(
      from_seer_visits: [
        {visit_occurrence: { icd9: '412' }},
        'Doctor'
      ]
    ).must_equal("observation"=>[1])

    criteria_ids(
      from_seer_visits: [
        {visit_occurrence: { icd9: '412' }},
        'Nurse'
      ]
    ).must_equal("observation"=>[2])

    criteria_ids(
      from_seer_visits: [
        {visit_occurrence: { icd9: '412' }},
        ['Doctor', 'Nurse']
      ]
    ).must_equal("observation"=>[1,2])
  end
end
