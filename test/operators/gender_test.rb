require_relative '../helper'

describe ConceptQL::Operators::Gender do
  it "should produce correct results" do
    criteria_ids("gender/crit_male",
      [:gender, 'male']
    )
  end

  it "should handle errors when annotating" do
    annotate("gender/anno_has_upstreams",
      [:gender, [:icd9, "412"]]
    )
  end
end

