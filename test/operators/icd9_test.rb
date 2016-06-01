require_relative '../helper'

describe ConceptQL::Operators::Icd9 do
  it "should produce correct results" do
    criteria_ids(
      [:icd9, '412']
    ).must_equal({"condition_occurrence"=>[2151, 2428, 3995, 4545, 4710, 5069, 5263, 5582, 8725, 10403, 10590, 11135, 11228, 11589, 11800, 13234, 13893, 14604, 14702, 14854, 14859, 17103, 17593, 23234, 23411, 24627, 25492, 26245, 27343, 37521, 38787, 50019, 50933, 52644, 52675, 53214, 53216, 53251, 53630, 53733, 53801, 55383, 56352, 56634, 56970, 57089, 57705, 58271, 58448, 58596, 58610, 58623, 59732, 59760, 59785]})
  end

  it "should handle errors when annotating" do
    query(
      [:icd9, 'XYS']
    ).annotate.must_equal(
      ["icd9", "XYS", {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>0, :n=>0}}, :warnings=>[["invalid source code", "XYS"]]}, :name=>"ICD-9 CM"}]
    )
  end

  it "should remove and ignore empty or blank labels" do
    query(
      [:icd9, '412', {:label => '   '}]
    ).annotate.must_equal(
      ["icd9", "412", {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>55, :n=>42}}}, :name=>"ICD-9 CM"}]
    )
  end
end
