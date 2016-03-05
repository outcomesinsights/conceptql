require_relative '../helper'

describe ConceptQL::Operators::Invalid do
  it "should show up in scope errors correctly" do
    query(
      [:cpt1, '123', { id: 1 }]
    ).scope_annotate.must_equal(
      {:errors=>{1 =>[["invalid operator", :cpt1]]}, :warnings=>{}, :counts=>{1=>{:invalid=>{:n=>0,:rows=>0}}}}
    )
  end
end

