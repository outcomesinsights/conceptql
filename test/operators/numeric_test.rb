require_relative '../helper'

describe ConceptQL::Operators::Numeric do
  it "should produce correct results" do
    numeric_values("numeric/num_values_1",
      [:numeric, 1]
    )

    numeric_values("numeric/num_values_2",
      [:numeric, 1, [:icd9_procedure, "00.13"]]
    )

    numeric_values("numeric/num_values_3",
      [:numeric, :criterion_id, [:icd9_procedure, "00.13"]]
    )
  end

  it "should handle errors when annotating" do
    annotate("numeric/anno_multiple_upstreams",
      [:numeric, [:icd9, "412"], [:icd9_procedure, "00.13"]]
    )
  end
end
