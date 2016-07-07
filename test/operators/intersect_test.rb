require_relative '../helper'

describe ConceptQL::Operators::Intersect do
  it "should produce correct results" do
    criteria_ids("intersect/crit_412_inpatient",
      [:intersect, [:icd9, "412"], [:condition_type, :inpatient_header]]
    )

    criteria_ids("intersect/crit_412_male",
      [:intersect, [:icd9, "412"], [:gender, "Male"]]
    )

    criteria_ids("intersect/crit_complex",
      [:intersect,
       [:icd9, "412"],
       [:condition_type, :inpatient_header],
       [:gender, "Male"],
       [:race, "White"]]
    )
  end

  it "#annotate should work correctly" do
    annotate("intersect/anno_412_inpatient",
      [:intersect, [:icd9, "412"], [:condition_type, :inpatient_header]]
    )
  end

  it "should handle errors when annotating" do
    annotate("intersect/anno_no_upstream",
      [:intersect]
    )

    annotate("intersect/anno_has_arguments",
      [:intersect, 1]
    )
  end
end
