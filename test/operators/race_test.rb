require_relative '../helper'

describe ConceptQL::Operators::Race do
  it "should produce correct results" do
    criteria_ids("race/crit_1",
      [:race, 'Black or African American']
    )
  end

  it "should handle errors when annotating" do
    annotate("race/anno_1",
      [:race, 'Black or African American', [:icd9, "412"]]
    )
    annotate("race/anno_2",
      [:race]
    )
  end
end
