require_relative '../helper'

describe ConceptQL::Operators::From do
  it "should produce correct results" do
    dataset(
      from: 'person'
    ).count.must_equal(250)

    dataset(
      from: 'observation_period'
    ).count.must_equal(1)

    dataset(
      from: 'condition_occurrence'
    ).count.must_equal(34044)
  end
end
