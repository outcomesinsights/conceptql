require_relative '../helper'

describe ConceptQL::Operators::PersonFilter do
  it "should produce correct results" do
    criteria_ids("person_filter/crit_1",
      [:person_filter,
       {:left=>[:icd9, "412"], :right=>[:union, [:cpt, "99214"], [:gender, "Male"]]}]
    )

    criteria_counts("person_filter/crit_2",
      [:person_filter,
       {:left=>[:union, [:icd9, "412"], [:cpt, "99214"]], :right=>[:gender, "Male"]}]
    )

    criteria_ids("person_filter/crit_3",
      [:person_filter, {:left=>[:gender, "Male"], :right=>[:death, true]}]
    )

    criteria_ids("person_filter/crit_4",
      [:person_filter, {:left=>[:icd9, "412"], :right=>[:gender, "Male"]}]
    )

    criteria_ids("person_filter/crit_5",
      [:person_filter, {:left=>[:icd9, "412"], :right=>[:cpt, "99214"]}]
    )
  end
end
