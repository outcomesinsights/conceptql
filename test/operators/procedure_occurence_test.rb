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

  it "should handle errors when annotating" do
    query(
      [:procedure_occurrence, [:icd9, "412"], [:gender, "Male"]]
    ).annotate.must_equal(
      ["procedure_occurrence",
       ["icd9", "412", {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>50, :n=>38}}}, :name=>"ICD-9 CM"}],
       ["gender", "Male", {:annotation=>{:counts=>{:person=>{:rows=>126, :n=>126}}}}],
       {:annotation=>{:counts=>{:procedure_occurrence=>{:n=>0, :rows=>0}}, :errors=>[["has multiple upstreams", ["icd9", "gender"]]]}}]
    )

    query(
      [:procedure_occurrence, 21, [:icd9, "412"]]
    ).annotate.must_equal(
      ["procedure_occurrence",
       ["icd9", "412", {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>50, :n=>38}}}, :name=>"ICD-9 CM"}],
       21,
       {:annotation=>{:counts=>{:procedure_occurrence=>{:n=>0, :rows=>0}}, :errors=>[["has arguments", [21]]]}}]
    )
  end
end

