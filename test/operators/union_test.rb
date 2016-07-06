require_relative '../helper'

describe ConceptQL::Operators::Union do
  it "should produce correct results" do
    criteria_counts("union/cc_1",
      [:union, [:icd9, "412"], [:icd9, "401.9"]]
    )

    criteria_counts("union/cc_2",
      [:union, [:icd9, "412"], [:icd10, 'Z56.1']]
    )

    criteria_counts("union/cc_3",
      [:union, [:icd9, "412"], [:icd10, 'Z56.1'], [:icd9, "401.9"]]
    )

    criteria_counts("union/cc_4",
      [:union,
        [:union, [:icd9, "412"], [:icd10, 'Z56.1']],
        [:icd9, "401.9"]]
    )

    criteria_counts("union/cc_5",
      [:union,
       [:union, [:icd9, "412"], [:icd9, "401.9"]],
       [:place_of_service_code, "21"]]
    )
  end

  it "optimize should produce correct results" do
    optimized_criteria_counts("union/optcc_1",
      [:union, [:icd9, "412"], [:icd9, "401.9"]]
    )

    optimized_criteria_counts("union/optcc_2",
      [:union, [:icd9, "412"], [:icd10, 'Z56.1']]
    )

    optimized_criteria_counts("union/optcc_3",
      [:union, [:icd9, "412"], [:icd10, 'Z56.1'], [:icd9, "401.9"]]
    )

    optimized_criteria_counts("union/optcc_4",
      [:union,
        [:union, [:icd9, "412"], [:icd10, 'Z56.1']],
        [:icd9, "401.9"]]
    )

    optimized_criteria_counts("union/optcc_5",
      [:union,
        [:union, [:icd9, "412"], [:icd9, "401.9"]],
        [:union, [:icd9, "412"], [:icd9, "401.9"]]]
    )

    optimized_criteria_counts("union/optcc_6",
      [:union,
       [:union, [:icd9, "412"], [:icd9, "401.9"]],
       [:place_of_service_code, "21"]]
    )
  end

  it "annotate should produce correct results" do
    annotate("union/anno_1",
      [:union, [:icd9, "412"], [:icd9, "401.9"]]
    )

    annotate("union/anno_2",
      [:union,
       [:union, [:icd9, "412"], [:icd9, "401.9"]],
       [:place_of_service_code, "21"]]
    )
  end

  it "should handle errors when annotating" do
    annotate("union/anno_3",
      [:union]
    )

    annotate("union/anno_4",
      [:union, "123"]
    )

    annotate("union/anno_5",
      [:union, [:foo, "123"]]
    )

    annotate("union/anno_6",
      [:union, [:union, [:foo, "123"]]]
    )
  end

  it "should handle scope annotations" do
    scope_annotate("union/scanno_1",
      [:union]
    )

    scope_annotate("union/scanno_2",
      [:union, [:icd9, "412", "XYS", {:id=>1}], [:icd9, "401.9", {:id=>2}]]
    )
  end
end
