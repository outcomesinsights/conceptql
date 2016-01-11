require_relative '../helper'

describe ConceptQL::Operators::ObservationPeriod do
  it "should produce correct results" do
    criteria_ids(
      observation_period: { icd9: '412' }
    ).must_equal("observation_period"=>[1])

    criteria_ids(
      observation_period: { gender: 'Male' }
    ).must_equal("observation_period"=>[1])

    criteria_ids(
      observation_period: { gender: 'Female' }
    ).must_equal({})
  end
end
