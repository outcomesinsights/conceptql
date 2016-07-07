require_relative '../helper'

describe ConceptQL::Operators::Last do
  it "should produce correct results" do
    criteria_ids("last/crit_icd9",
      [:last, [:icd9, "412"]]
    )
  end
end

