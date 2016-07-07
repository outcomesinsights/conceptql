require_relative '../helper'

describe ConceptQL::Operators::Occurrence do
  it "should produce correct results" do
    criteria_ids("occurrence/crit_1",
      [:occurrence, 2, [:icd9, "412"]]
    )

    criteria_ids("occurrence/crit_2",
      [:occurrence, 2, [:icd9, "412"], {:unique=>true}]
    )

    criteria_ids("occurrence/crit_3",
      [:occurrence, -1, [:icd9, "412"], {:unique=>true}]
    )
  end

  it "should handle errors when annotating" do
    annotate("occurrence/anno_no_upstream",
      [:occurrence]
    )
  end

  it "should have a unique name per CTE" do
    criteria_counts("occurrence/count_412_410",
      [:union, [:first, [:icd9,  "412"] ], [:first, [:icd9,  "410"] ]]
    )
  end
end
