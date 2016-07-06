require_relative '../helper'

describe ConceptQL::Operators::Sum do
  it "should produce correct results" do
    numeric_values("sum/num_1",
      [:sum, [:numeric, 1, [:ndc, "12745010902"]]]
    )

    numeric_values("sum/num_2",
      [:sum, [:icd9_procedure, "00.13"], [:numeric, 1, [:ndc, "12745010902"]]]
    )

    numeric_values("sum/num_3",
      [:sum, [:numeric, 1]]
    )
  end

  it "should handle errors when annotating" do
    annotate("sum/anno_1",
      [:sum]
    )

    annotate("sum/anno_2",
      [:sum, 21, [:numeric, 1]]
    )
  end
end
