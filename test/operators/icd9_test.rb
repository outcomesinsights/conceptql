require_relative '../helper'

describe ConceptQL::Operators::Icd9 do
  it "should produce correct results" do
    criteria_ids("icd9/crit_1",
      [:icd9, '412']
    )
  end

  it "should handle errors when annotating" do
    annotate("icd9/anno_invalid_code",
      [:icd9, 'XYS']
    )
  end

  it "should remove and ignore empty or blank labels" do
    annotate("icd9/anno_empty_label",
      [:icd9, '412', {:label => '   '}]
    )
  end
end
