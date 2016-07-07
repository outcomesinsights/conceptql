require_relative '../helper'

describe ConceptQL::Operators::Before do
  it "should produce correct results" do
    criteria_ids("before/crit_basic1",
      [:before, {:left=>[:icd9, "412"], :right=>[:icd9, "401.9"]}]
    )

    criteria_ids("before/crit_basic2",
      [:before, {:left=>[:icd9, "412"], :right=>[:first, [:icd9, "401.9"]]}]
    )
  end

  it "should produce correct results when using :within option" do
    criteria_ids("before/crit_within",
      [:before, {:left=>[:icd9, "412"], :right=>[:icd9, "401.9"], :within=>'30d'}]
    )
  end

  it "should produce correct results when using :at_least option" do
    criteria_ids("before/crit_at_least",
      [:before, {:left=>[:icd9, "412"], :right=>[:icd9, "401.9"], :at_least=>'900d'}]
    )
  end

  it "should produce correct results when using :occurrences option" do
    criteria_ids("before/crit_occurrences",
      [:before, {:left=>[:icd9, "412"], :right=>[:icd9, "401.9"], :occurrences=>1}]
    )
  end
end
