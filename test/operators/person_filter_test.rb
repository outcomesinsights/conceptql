require_relative '../helper'

describe ConceptQL::Operators::PersonFilter do
  it "should produce correct results" do
    criteria_ids(
      person_filter: {
        left: { icd9: '412' },
        right: {
          union: [
            { cpt: '99214' },
            { gender: 'Male' }
          ]
        }
      }
    ).must_equal("condition_occurrence"=>[1712, 1829, 4359, 5751, 6083, 6902, 7865, 8397, 8618, 9882, 10196, 10443, 10865, 13016, 13741, 15149, 17041, 17772, 17774, 18412, 18555, 19736, 20005, 20037, 21006, 21619, 21627, 22875, 22933, 24437, 24471, 24707, 24721, 24989, 25309, 25417, 25875, 25888, 26766, 27388, 28177, 28188, 30831, 31387, 31542, 31792, 31877, 32104, 32463, 32981])

    criteria_counts(
      person_filter: {
        left: {
          union: [
             { icd9: '412' },
             { cpt: '99214' }
          ]
        },
        right: { gender: 'Male' }
      }
    ).must_equal("condition_occurrence"=>56, "procedure_occurrence"=>609)

    criteria_ids(
      person_filter: {
        left: { gender: 'Male' },
        right: { death: true },
      }
    ).must_equal("person"=>[177])

    criteria_ids(
      person_filter: {
        left: { icd9: '412' },
        right: { gender: 'Male'}
      }
    ).must_equal("condition_occurrence"=>[5751, 6083, 10865, 13741, 15149, 17041, 17772, 17774, 18412, 21619, 21627, 22933, 24437, 24471, 24707, 24721, 25309, 25417, 25875, 25888, 26766, 28177, 28188, 30831, 31877, 32104, 32463, 32981])

    criteria_ids(
      person_filter: {
        left: { icd9: '412' },
        right: { cpt: '99214' }
      }
    ).must_equal("condition_occurrence"=>[1712, 1829, 4359, 5751, 6083, 6902, 7865, 8397, 8618, 9882, 10196, 10443, 10865, 13016, 13741, 15149, 17041, 17772, 17774, 18412, 18555, 19736, 20005, 20037, 21006, 21619, 21627, 22875, 22933, 24707, 24721, 24989, 25309, 25417, 25875, 25888, 26766, 27388, 28177, 28188, 30831, 31387, 31542, 31792, 31877, 32104, 32463, 32981])
  end
end
