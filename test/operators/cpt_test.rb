require_relative '../helper'

describe ConceptQL::Operators::Cpt do
  it "should produce correct results" do
    criteria_counts("cpt/crit_1",
      [:cpt, "99214"]
    ).must_equal("procedure_occurrence"=>1221)

    criteria_ids(("cpt/crit_1",
      [:cpt, "99215"]
    ).must_equal("procedure_occurrence"=>[78, 330, 387, 788, 995, 2043, 2078, 2838, 3128, 3141, 3243, 3423, 3457, 3561, 3568, 3661, 3785, 4087, 4217, 4351, 4525, 4649, 4736, 4746, 4837, 5017, 5622, 5632, 5796, 5938, 5999, 6064, 6189, 6346, 6737, 7399, 7728, 8564, 8675, 8970, 9043, 9230, 9332, 9411, 9511, 9542, 9817, 9831, 10534, 10763, 11061, 11107, 11152, 11385, 11739, 11740, 11922, 12004, 12169, 12445, 12477, 12559, 12895, 13069, 13131, 13330, 13494, 13804, 13841, 13943, 13989, 14052, 14182, 14346, 14410, 15049, 15963, 16004, 16110, 16772, 16988, 17158, 17555, 17746, 17875, 17952, 18131, 18234, 18506, 19012, 19372, 19413, 19685, 19697, 19767, 19770, 19784, 19943, 19961, 20042, 20137, 20307, 20370, 20404, 20409, 20757, 20887, 20904, 21215, 21217, 21466, 21642, 21750, 22104, 22662, 22778, 22920, 22993, 23071, 23090, 23365, 23369, 23378, 24535, 25096, 25504, 25587, 25638, 26853, 27062, 27110, 27113, 27114, 27616, 27852, 27970, 28217, 28223, 28331, 28340, 28644, 29081, 29402, 29424, 29515, 29548, 29584, 29660, 29762, 29881, 29959, 30389, 30549, 30765, 31645, 31693, 31748, 31755, 33061, 33179, 33303, 33542, 33869, 34091, 34136, 34783, 34958, 35113, 35366, 35572])
  end

  it "should handle errors when annotating" do
    annotate("cpt/anno_icd9_upstream",
      [:cpt, [:icd9, "412"]]
    ).annotate.must_equal(
      ["cpt",
       ["icd9", "412", {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>50, :n=>38}}}, :name=>"ICD-9 CM"}],
       {:annotation=>{:counts=>{:condition_occurrence=>{:n=>0, :rows=>0}}, :errors=>[["has upstreams", ["icd9"]], ["has no arguments"]]}, :name=>"CPT"}]
    )

    annotate("cpt/anno_invalid_code",
      [:cpt, "99214", "XYS"]
    ).annotate.must_equal(
      ["cpt", "99214", "XYS", {:annotation=>{:counts=>{:procedure_occurrence=>{:rows=>1221, :n=>203}}, :warnings=>[["invalid concept code", "XYS"]]}, :name=>"CPT"}]
    )
  end

  it "should show operators when annotating" do
    # TODO this is more complex
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
