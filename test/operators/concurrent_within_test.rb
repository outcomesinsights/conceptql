require_relative '../helper'

describe ConceptQL::Operators::ConcurrentWithin do
  it "should produce correct results" do
    criteria_ids("concurrent_within/crit_icd9",
      [:concurrent_within, [:icd9, "412"], {:start=>"-2y", :end=>"-2y"}]
    )

    criteria_ids("concurrent_within/crit_icd9_and_place_of_service",
      [:concurrent_within, [:icd9, "412"], [:place_of_service_code, "21"], {:start=>"1d", :end=>"1d"}]
    )

    criteria_ids("concurrent_within/crit_negative_start",
      [:concurrent_within, [:icd9, "412"], [:place_of_service_code, "21"], {:start=>"-1d", :end=>"0d"}]
    )
  end
end
