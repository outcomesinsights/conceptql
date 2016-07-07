require_relative '../helper'

describe ConceptQL::Operators::ObservationPeriod do
  it "should produce correct results" do
    criteria_ids("observation_period/crit_icd9",
      [:observation_period, [:icd9, '412']]
    )

    criteria_ids("observation_period/crit_male",
      [:observation_period, [:gender, 'Male']]
    )

    criteria_ids("observation_period/crit_female",
      [:observation_period, [:gender, 'Female']]
    )
  end

  it "should handle errors when annotating" do
    annotate("observation_period/anno_multiple_upstreams",
      [:observation_period, [:icd9, '412'], [:gender, 'Male']]
    )

    annotate("observation_period/anno_has_arguments",
      [:observation_period, 1, [:gender, 'Male']]
    )
  end
end
