require_relative '../helper'

describe ConceptQL::Operators::ProcedureOccurrence do
  it "should produce correct results" do
    criteria_counts("procedure_occurrence/crit_icd9",
      [:procedure_occurrence, [:icd9, "412"]]
    )

    criteria_counts("procedure_occurrence/crit_gender",
      [:procedure_occurrence, [:gender, "Male"]]
    )

    criteria_counts("procedure_occurrence/crit_started_by",
      [:procedure_occurrence,
       [:started_by,
        {:left=>[:icd9, "412"],
         :right=>[:date_range, {:start=>"2008-03-14", :end=>"2008-03-20"}]}]]
    )
  end

  it "should handle errors when annotating" do
    annotate("procedure_occurrence/anno_multiple_upstreams",
      [:procedure_occurrence, [:icd9, "412"], [:gender, "Male"]]
    )

    annotate("procedure_occurrence/anno_has_arguments",
      [:procedure_occurrence, 21, [:icd9, "412"]]
    )
  end
end

