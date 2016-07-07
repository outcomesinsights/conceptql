require_relative '../helper'

describe ConceptQL::Operators::Except do
  it "should produce correct results" do
    criteria_ids("except/crit_412_inpatient",
      [:except,
       {:left=>[:icd9, "412"], :right=>[:condition_type, :inpatient_header]}]
    )

    criteria_ids("except/crit_412_cpt",
      [:except, {:left=>[:icd9, "412"], :right=>[:cpt, "99214"]}]
    )

    criteria_counts("except/count_complex",
      [:except,
       {:left=>[:union, [:icd9, "412"], [:gender, "Male"], [:cpt, "99214"]],
        :right=>[:union, [:condition_type, :inpatient_header], [:race, "White"]]}]
    )
  end

  it "annotate should work correctly" do
    annotate("except/anno_1",
      [:except,
       {:left=>[:icd9, "412"], :right=>[:condition_type, :inpatient_header]}]
    )

    annotate("except/anno_2",
      [:except,
       {:left=>[:icd9, "412"], :right=>[:condition_type, :inpatient_header], :foo=>true}]
    )
  end
end
