require_relative '../helper'

describe ConceptQL::Operators::Visit do
  it "should produce correct results" do
    criteria_counts(
      [:visit]
    ).must_equal("visit_occurrence"=>14931)

    criteria_counts(
      [:visit, [:icd9, "412"]]
    ).must_equal("visit_occurrence"=>3771)

    criteria_ids(
      [:visit, [:ndc, "12745010902"]]
    ).must_equal("visit_occurrence"=>[6640, 6641, 6642, 6643, 6644, 6645, 6646, 6647, 6648, 6649, 6650, 6651, 6652, 6653, 6654, 6655, 6656, 6657, 6658, 6659, 6660, 6661, 6662, 6663, 6664, 6665, 6666, 6667, 6668, 6669, 6670, 6671, 6672, 6673, 6674, 6675, 6676, 6677, 6678, 6679, 6680, 6681, 6682, 6683, 6684, 6685, 6686, 6687, 6688, 6689, 6690, 6691, 6692, 6693, 6694, 6695, 6696, 6697, 6698, 6699, 6700, 6701, 6702, 6703, 6704, 6705, 6706, 6707, 6708, 6709, 6710, 6711, 6712, 6713, 6714, 6715, 6716, 6717])
  end

  it "should handle errors when annotating" do
    query(
      [:visit, [:icd9, "412"], [:icd9, "412"]]
    ).annotate.must_equal(
      ["visit",
       ["icd9", "412", {:annotation=>{:condition_occurrence=>{:rows=>50, :n=>38}}, :name=>"ICD-9 CM"}],
       ["icd9", "412", {:annotation=>{:condition_occurrence=>{:rows=>50, :n=>38}}, :name=>"ICD-9 CM"}],
       {:annotation=>{:errors=>[["has multiple upstreams"]]}}]
    )

    query(
      [:visit, 21, [:icd9, "412"]]
    ).annotate.must_equal(
      ["visit",
       ["icd9", "412", {:annotation=>{:condition_occurrence=>{:rows=>50, :n=>38}}, :name=>"ICD-9 CM"}],
       21,
       {:annotation=>{:errors=>[["has arguments"]]}}]
    )
  end
end
