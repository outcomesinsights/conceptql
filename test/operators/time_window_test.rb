require_relative '../helper'

describe ConceptQL::Operators::TimeWindow do
  it "should produce correct results" do
    criteria_ids("time_window/crit_1",
      [:time_window, [:icd9, "412"], {:start=>"-2y", :end=>"-2y"}]
    )

    criteria_ids("time_window/crit_2",
      [:time_window, [:place_of_service_code, "21"], {:start=>"", :end=>"start"}]
    )

    criteria_ids("time_window/crit_3",
      [:time_window, [:icd9, "412"], {:start=>"-2m-2d", :end=>"3d1y"}]
    )

    criteria_ids("time_window/crit_4",
      [:time_window, [:place_of_service_code, "21"], {:start=>"end", :end=>"start"}]
    )
  end

  it "should handle errors when annotating" do
    annotate("time_window/anno_1",
      [:time_window, {:start=>"-2y", :end=>"-2y"}]
    )

    annotate("time_window/anno_2",
      [:time_window, [:icd9, "412"], {:start=>2, :end=>2}]
    )

    annotate("time_window/anno_3",
      [:time_window, [:icd9, "412"], {:start=>"-2b", :end=>"-2y"}]
    )

    annotate("time_window/anno_4",
      [:time_window, 21, [:icd9, "412"], {:start=>"-2y", :end=>"-2y"}]
    )

    annotate("time_window/anno_5",
      [:time_window, [:icd9, "412"], [:place_of_service_code, "21"], {:start=>"-2y", :end=>"-2y"}]
    )
  end
end
