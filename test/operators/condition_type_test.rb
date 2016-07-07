require_relative '../helper'

describe ConceptQL::Operators::ConditionType do
  it "should produce correct results" do
    criteria_counts("condition_type/count_inpatient",
      [:condition_type, 'inpatient']
    )

    criteria_counts("condition_type/count_outpatient",
      [:condition_type, 'outpatient']
    )

    criteria_counts("condition_type/count_inpatient_primary",
      [:condition_type, 'inpatient_primary']
    )

    criteria_counts("condition_type/count_inpatient_primary_or_first",
      [:condition_type, 'inpatient_primary_or_first']
    )

    criteria_counts("condition_type/count_outpatient_primary",
      [:condition_type, 'outpatient_primary']
    )

    criteria_counts("condition_type/count_primary",
      [:condition_type, 'primary']
    )

    criteria_counts("condition_type/count_ehr_problem_list",
      [:condition_type, 'ehr_problem_list']
    )

    criteria_counts("condition_type/count_condition_era",
      [:condition_type, 'condition_era']
    )

    criteria_counts("condition_type/count_era_0",
      [:condition_type, 'condition_era_0_day_window']
    )

    criteria_counts("condition_type/count_condition_era_30_day_window",
      [:condition_type, 'condition_era_30_day_window']
    )

    criteria_counts("condition_type/count_primary",
      [:condition_type, 'primary']
    )

    criteria_counts("condition_type/count_outpatient_detail",
      [:condition_type, 'outpatient_detail']
    )

    criteria_counts("condition_type/count_outpatient_header",
      [:condition_type, 'outpatient_header']
    )

    criteria_counts("condition_type/count_inpatient_detail",
      [:condition_type, 'inpatient_detail']
    )

    criteria_counts("condition_type/count_inpatient_header",
      [:condition_type, 'inpatient_header']
    )

    criteria_counts("condition_type/count_inpatient_header_2",
      [:condition_type, 'inpatient_header_2']
    )

    criteria_counts("condition_type/count_inpatient_header_3",
      [:condition_type, 'inpatient_header_3']
    )

    criteria_counts("condition_type/count_inpatient_header_4",
      [:condition_type, 'inpatient_header_4']
    )

    criteria_counts("condition_type/count_inpatient_header_5",
      [:condition_type, 'inpatient_header_5']
    )

    criteria_counts("condition_type/count_outpatient_detail",
      [:condition_type, 'inpatient', 'outpatient_detail']
    )
  end

  it "should handle upstream errors in annotations" do
    annotate("condition_type/anno_icd9",
      [:condition_type, [:icd9, "412"]]
    )
  end
end
