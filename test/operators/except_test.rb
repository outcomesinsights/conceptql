require_relative '../helper'

describe ConceptQL::Operators::Except do
  it "should produce correct results" do
    criteria_ids(
      [:except,
       {:left=>[:icd9, "412"], :right=>[:condition_type, :inpatient_header]}]
    ).must_equal("condition_occurrence"=>[2151, 2428, 3995, 4545, 4710, 5069, 5263, 5582, 8725, 10403, 10590, 11135, 11228, 11589, 11800, 13234, 13893, 14604, 14702, 14854, 14859, 17103, 17593, 23234, 23411, 24627, 25492, 26245, 27343, 37521, 38787, 50019, 50933, 55383, 56352, 56634, 56970, 57089, 57705, 58271, 58448, 58596, 58610, 58623, 59732, 59760, 59785])

    criteria_ids(
      [:except, {:left=>[:icd9, "412"], :right=>[:cpt, "99214"]}]
    ).must_equal("condition_occurrence"=>[2151, 2428, 3995, 4545, 4710, 5069, 5263, 5582, 8725, 10403, 10590, 11135, 11228, 11589, 11800, 13234, 13893, 14604, 14702, 14854, 14859, 17103, 17593, 23234, 23411, 24627, 25492, 26245, 27343, 37521, 38787, 50019, 50933, 52644, 52675, 53214, 53216, 53251, 53630, 53733, 53801, 55383, 56352, 56634, 56970, 57089, 57705, 58271, 58448, 58596, 58610, 58623, 59732, 59760, 59785])

    criteria_counts(
      [:except,
       {:left=>[:union, [:icd9, "412"], [:gender, "Male"], [:cpt, "99214"]],
        :right=>[:union, [:condition_type, :inpatient_header], [:race, "White"]]}]
    ).must_equal("condition_occurrence"=>47, "procedure_occurrence"=>1224, "person"=>126)
  end

  it "annotate should work correctly" do
    query(
      [:except,
       {:left=>[:icd9, "412"], :right=>[:condition_type, :inpatient_header]}]
    ).annotate.must_equal(["except",
      {:left=>["icd9", "412", {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>55, :n=>42}}}, :name=>"ICD-9 CM"}],
       :right=>["condition_type", :inpatient_header, {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>1542, :n=>92}}}}],
       :annotation=>{:counts=>{:condition_occurrence=>{:rows=>47, :n=>37}}}}
    ])

    query(
      [:except,
       {:left=>[:icd9, "412"], :right=>[:condition_type, :inpatient_header], :foo=>true}]
    ).annotate.must_equal(["except",
      {:left=>["icd9", "412", {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>55, :n=>42}}}, :name=>"ICD-9 CM"}],
       :right=>["condition_type", :inpatient_header, {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>1542, :n=>92}}}}],
       :foo=>true,
       :annotation=>{:counts=>{:condition_occurrence=>{:rows=>47, :n=>37}}}}
    ])
  end
end
