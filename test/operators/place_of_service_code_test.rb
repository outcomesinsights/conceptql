require_relative '../helper'

describe ConceptQL::Operators::PlaceOfServiceCode do
  it "should produce correct results" do
    criteria_ids("place_of_service_code/crit_basic",
      [:place_of_service_code, 21]
    )
  end

  it "should handle errors when annotating" do
    annotate("place_of_service_code/anno_has_upstreams",
      [:place_of_service_code, 21, [:icd9, "412"]]
    )

    annotate("place_of_service_code/anno_no_arguments",
      [:place_of_service_code]
    )
  end
end
