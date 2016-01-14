require_relative '../helper'

describe ConceptQL::Operators::ProcedureOccurrence do
  it "should produce correct results" do
    criteria_counts(
      [:procedure_occurrence, [:icd9, "412"]]
    ).must_equal("procedure_occurrence"=>9380)

    criteria_counts(
      [:procedure_occurrence, [:gender, "Male"]]
    ).must_equal("procedure_occurrence"=>18107)

    criteria_counts(
      [:procedure_occurrence,
       [:started_by,
        {:left=>[:icd9, "412"],
         :right=>[:date_range, {:start=>"2008-03-14", :end=>"2008-03-20"}]}]]
    ).must_equal("procedure_occurrence"=>592)
  end
end

