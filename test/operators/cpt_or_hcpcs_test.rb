require_relative '../helper'

describe ConceptQL::Operators::CptOrHcpcs do
  it "should produce correct results" do
    criteria_counts("cpt_or_hcpcs/count_1",
      [:cpt_or_hcpcs, '99214', 'A0382']
    )

    criteria_ids("cpt_or_hcpcs/crit_1",
      [:cpt_or_hcpcs, '99215', 'A0382']
    )
  end
end
