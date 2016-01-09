require_relative '../helper'

describe ConceptQL::Operators::Last do
  it "should produce correct results" do
    criteria_ids(
      last: { icd9: '412'}
    ).must_equal("condition_occurrence"=>[1829, 4359, 5751, 6083, 6902, 7865, 8397, 8618, 10196, 10443, 10865, 13016, 13741, 15149, 17041, 17774, 18412, 18555, 19736, 20005, 21006, 21619, 22875, 22933, 24437, 24707, 24989, 25309, 25888, 26766, 27388, 28188, 30831, 31542, 31792, 31877, 32463, 32981])
  end
end

