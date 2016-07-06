require_relative '../helper'

describe ConceptQL::Operators::Read do
  it "should produce correct results" do
    criteria_ids("read/crit_1",
      [:read, "283Z.00"]
    )
  end

  it "should handle errors when annotating" do
    annotate("read/anno_1",
      [:read, 'XYS']
    )
  end
end
