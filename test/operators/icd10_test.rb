require_relative '../helper'

describe ConceptQL::Operators::Icd10 do
  it "should produce correct results" do
    criteria_ids("icd10/crit_1",
      [:icd10, 'Z56.1']
    )
  end

  it "should handle errors when annotating" do
    annotate("icd10/anno_has_upstreams",
      [:icd10, [:icd9, "412"]]
    )
  end
end
