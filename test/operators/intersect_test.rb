require_relative '../helper'

describe ConceptQL::Operators::Intersect do
  it "should produce correct results" do
    criteria_ids(
      [:intersect, [:icd9, "412"], [:condition_type, :inpatient_header]]
    ).must_equal("condition_occurrence"=>[52644, 52675, 53214, 53216, 53251, 53630, 53733, 53801])

    criteria_ids(
      [:intersect, [:icd9, "412"], [:gender, "Male"]]
    ).must_equal("person"=>[1, 2, 4, 5, 6, 7, 8, 12, 14, 20, 21, 23, 25, 27, 28, 38, 40, 45, 51, 53, 55, 59, 60, 63, 65, 66, 68, 69, 70, 73, 78, 80, 82, 85, 90, 91, 92, 94, 95, 96, 99, 101, 106, 107, 108, 109, 110, 112, 113, 115, 117, 119, 120, 125, 127, 128, 129, 130, 131, 132, 138, 142, 143, 145, 146, 148, 149, 150, 152, 153, 154, 158, 161, 163, 164, 172, 174, 175, 177, 178, 181, 182, 183, 187, 189, 191, 192, 195, 198, 203, 205, 206, 207, 212, 215, 218, 222, 227, 229, 230, 231, 233, 238, 239, 244, 245, 246, 249, 251, 260, 262, 265, 266, 268, 270, 271, 273, 274, 275, 276, 279, 280, 285, 287, 288, 289],
                 "condition_occurrence"=>[2151, 2428, 3995, 4545, 4710, 5069, 5263, 5582, 8725, 10403, 10590, 11135, 11228, 11589, 11800, 13234, 13893, 14604, 14702, 14854, 14859, 17103, 17593, 23234, 23411, 24627, 25492, 26245, 27343, 37521, 38787, 50019, 50933, 52644, 52675, 53214, 53216, 53251, 53630, 53733, 53801, 55383, 56352, 56634, 56970, 57089, 57705, 58271, 58448, 58596, 58610, 58623, 59732, 59760, 59785])

    criteria_ids(
      [:intersect,
       [:icd9, "412"],
       [:condition_type, :inpatient_header],
       [:gender, "Male"],
       [:race, "White"]]
    ).must_equal("person"=>[1, 2, 5, 7, 8, 12, 14, 20, 23, 25, 27, 28, 38, 40, 45, 51, 53, 55, 59, 60, 63, 65, 68, 78, 80, 82, 85, 90, 91, 92, 95, 96, 99, 101, 107, 108, 110, 112, 119, 120, 125, 127, 128, 130, 131, 132, 138, 142, 143, 145, 146, 149, 150, 152, 153, 154, 158, 161, 164, 172, 174, 175, 178, 181, 183, 187, 189, 191, 192, 195, 203, 205, 206, 207, 212, 215, 218, 222, 227, 229, 231, 233, 238, 239, 244, 245, 246, 249, 251, 262, 266, 268, 270, 271, 273, 274, 275, 276, 279, 280, 285, 287, 288, 289],
                 "condition_occurrence"=>[6083, 8618, 9882, 15149, 18412, 20005, 26766, 31877])
  end

  it "#annotate should work correctly" do
    query(
      [:intersect, [:icd9, "412"], [:condition_type, :inpatient_header]]
    ).annotate.must_equal(["intersect",
      ["icd9", "412", {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>55, :n=>42}}}, :name=>"ICD-9 CM"}],
      ["condition_type", :inpatient_header, {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>1542, :n=>92}}}}],
      {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>8, :n=>8}}}}
    ])
  end

  it "should handle errors when annotating" do
    query(
      [:intersect]
    ).annotate.must_equal(
      ["intersect", {:annotation=>{:counts=>{:invalid=>{:n=>0, :rows=>0}}, :errors=>[["has no upstream"]]}}]
    )

    query(
      [:intersect, 1]
    ).annotate.must_equal(
      ["intersect", 1, {:annotation=>{:counts=>{:invalid=>{:n=>0, :rows=>0}}, :errors=>[["has no upstream"], ["has arguments", [1]]]}}]
    )
  end
end
