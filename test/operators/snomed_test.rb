require_relative '../helper'

describe ConceptQL::Operators::Snomed do
  it "should produce correct results" do
    criteria_ids("snomed/crit_1",
      [:snomed, '271594007']
    )
  end
end

