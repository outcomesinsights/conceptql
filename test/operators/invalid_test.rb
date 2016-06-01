require_relative '../helper'

describe ConceptQL::Operators::Invalid do
  it "should show up in scope errors correctly" do
    query(
      [:cpt1, '123', { id: 1 }]
    ).scope_annotate.must_equal(
      {:errors=>{1 =>[["invalid operator", :cpt1]]}, :warnings=>{}, :counts=>{1=>{:invalid=>{:n=>0,:rows=>0}}}, :operators=>["cpt1"]}
    )
  end

  it "should annotate left and right options if provided" do
    query(
      [:bad_op, {left: [:icd9, "412"], right: [:icd9, "410"]}]
    ).annotate.must_equal(
      ["bad_op", {
        :left=>["icd9", "412", {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>55, :n=>42}}}, :name=>"ICD-9 CM"}],
        :right=>["icd9", "410", {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>0, :n=>0}}}, :name=>"ICD-9 CM"}],
        :annotation=>{:counts=>{:invalid=>{:rows=>0, :n=>0}}, :errors=>[["invalid operator", :bad_op]]}}]
    )
  end
end

