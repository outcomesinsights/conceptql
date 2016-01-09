require_relative '../helper'

describe ConceptQL::Operators::Death do
  it "should produce correct results" do
    criteria_ids(
      death: true
    ).must_equal("death"=>[177])
  end
end
