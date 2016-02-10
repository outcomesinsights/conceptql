require_relative '../helper'

describe ConceptQL::Operators::Icd9 do
  it "should produce correct results" do
    criteria_ids(
      [:icd9, '412']
    ).must_equal({"condition_occurrence"=>[1712, 1829, 4359, 5751, 6083, 6902, 7865, 8397, 8618, 9882, 10196, 10443, 10865, 13016, 13741, 15149, 17041, 17772, 17774, 18412, 18555, 19736, 20005, 20037, 21006, 21619, 21627, 22875, 22933, 24437, 24471, 24707, 24721, 24989, 25309, 25417, 25875, 25888, 26766, 27388, 28177, 28188, 30831, 31387, 31542, 31792, 31877, 32104, 32463, 32981]})
  end

  it "should handle errors when annotating" do
    query(
      [:icd9, 'XYS']
    ).annotate.must_equal(
      ["icd9", "XYS", {:annotation=>{:condition_occurrence=>{:rows=>0, :n=>0}, :warnings=>[["invalid source code", "XYS"]]}, :name=>"ICD-9 CM"}]
    )
  end
end
