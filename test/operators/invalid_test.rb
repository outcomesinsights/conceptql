require_relative '../helper'

describe ConceptQL::Operators::Invalid do
  it "should show up in scope errors correctly" do
    scope_annotate("invalid/scope_annotate_1",
      [:cpt1, '123', { id: 1 }]
    )
  end

  it "should annotate left and right options if provided" do
    annotate("invalid/anno_bad_op",
      [:bad_op, {left: [:icd9, "412"], right: [:icd9, "ZZZZZZZ"]}]
    )
  end
end

