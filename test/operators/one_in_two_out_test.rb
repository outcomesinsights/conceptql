require_relative '../helper'

describe ConceptQL::Operators::OneInTwoOut do
  it "should produce correct results" do
    criteria_ids("one_in_two_out/crit_icd9",
      [:one_in_two_out, [:icd9, "412"], {:min_gap=>30, :blah=>true}]
    )
  end

  it "should treat non-conditions as inpatient" do
    criteria_ids("one_in_two_out/crit_hcpcs",
      [:one_in_two_out, [:hcpcs, 'A0382'] , {:min_gap=>30}]
    )

  end

  it "should handle errors when annotating" do
    annotate("one_in_two_out/anno_no_upstream",
      [:one_in_two_out, {:gap=>30, :blah=>true}]
    )

    annotate("one_in_two_out/anno_has_arguments",
      [:one_in_two_out, 1, {:gap=>30, :blah=>true}]
    )

    annotate("one_in_two_out/anno_multiple_upstreams",
      [:one_in_two_out, [:icd9, "412"], [:icd9, "412"], {:gap=>30, :blah=>true}]
    )
  end
end
