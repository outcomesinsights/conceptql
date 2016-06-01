require_relative '../helper'

describe ConceptQL::Operators::Cpt do
  it "should produce correct results" do
    criteria_counts(
      [:cpt, "99214"]
    ).must_equal("procedure_occurrence"=>1224)

    criteria_ids(
      [:cpt, "99215"]
    ).must_equal("procedure_occurrence"=>[71, 93, 193, 346, 377, 385, 452, 507, 544, 576, 587, 596, 628, 684, 734, 850, 955, 1020, 1047, 1173, 1202, 1232, 1289, 1325, 1430, 1567, 1602, 1736, 1925, 1968, 1994, 2009, 2025, 2129, 2254, 2320, 2363, 2459, 2628, 2783, 2863, 3055, 3151, 3178, 3244, 3430, 3486, 3570, 3970, 4010, 4101, 4132, 4176, 4263, 4288, 4310, 4327, 4329, 4401, 4444, 4451, 4480, 4814, 4911, 5213, 5524, 5601, 5770, 5878, 6149, 6204, 6254, 6386, 6429, 6625, 6688, 6771, 6837, 6873, 6993, 7039, 7060, 7154, 7159, 7213, 7291, 7415, 7451, 7460, 7472, 7490, 7539, 7566, 7626, 7644, 7706, 7787, 7838, 7879, 8048, 8277, 8297, 8369, 8502, 8529, 8590, 8601, 8667, 8793, 8898, 8900, 8990, 9016, 9182, 9360, 9390, 9403, 9467, 9492, 9862, 9871, 9942, 10055, 10137, 10272, 10307, 10385, 10409, 10427, 10548, 10555, 10602, 10699, 10756, 10774, 10940, 11111, 11186, 11212, 11222, 11408, 11601, 11671, 11766, 11831, 11925, 11965, 12006, 12047, 12100, 12333, 12396, 12485, 12490, 12802, 17048, 17733, 17867, 19475, 19790, 20617, 20725, 23056, 24732, 24826, 25324, 26615, 29077, 30331, 32898, 35218])
  end

  it "should handle errors when annotating" do
    query(
      [:cpt, [:icd9, "412"]]
    ).annotate.must_equal(
      ["cpt",
       ["icd9", "412", {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>55, :n=>42}}}, :name=>"ICD-9 CM"}],
       {:annotation=>{:counts=>{:condition_occurrence=>{:n=>0, :rows=>0}}, :errors=>[["has upstreams"], ["has no arguments"]]}, :name=>"CPT"}]
    )

    query(
      [:cpt, "99214", "XYS"]
    ).annotate.must_equal(
      ["cpt", "99214", "XYS", {:annotation=>{:counts=>{:procedure_occurrence=>{:rows=>1224, :n=>203}}, :warnings=>[["invalid concept code", "XYS"]]}, :name=>"CPT"}]
    )
  end

  it "should show operators when annotating" do
    query(
      [:cpt, "99214"]
    ).scope_annotate.must_equal({
        :counts=>{
          "cpt"=>{
            :procedure_occurrence=>{:rows=>1221, :n=>203}
          }
        },
        :operators=>["cpt"],
        :errors=>{},
        :warnings=>{}
      }
    )
  end
end
