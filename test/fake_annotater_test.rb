require_relative 'helper'
require 'conceptql/fake_annotater'

describe ConceptQL::FakeAnnotater do
  it "should work correctly for operators with single values" do
    ConceptQL::FakeAnnotater.new([:icd9, '412']).annotate.must_equal [:icd9, "412", {:annotation=>{:counts=>{:condition_occurrence=>{}}}}]
  end

  it "should work correctly for operators with multiple values" do
    ConceptQL::FakeAnnotater.new([:icd9, '411', '412']).annotate.must_equal [:icd9, "411", "412", {:annotation=>{:counts=>{:condition_occurrence=>{}}}}]
  end

  it "should work correctly for operators with hash arguments" do
    ConceptQL::FakeAnnotater.new(
      [:any_overlap,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2010-01-01", :end=>"2010-12-31"}]}]
     ).annotate.must_equal([:any_overlap,
       {:left=>[:icd9, "412", {:annotation=>{:counts=>{:condition_occurrence=>{}}}}],
        :right=>[:date_range, {:start=>"2010-01-01", :end=>"2010-12-31", :annotation=>{:counts=>{:date=>{}}}}], :annotation=>{:counts=>{:condition_occurrence=>{}}}}
     ])
  end

  it "should work correctly for operators with upsreams" do
    ConceptQL::FakeAnnotater.new([:union, [:icd9, "412"], [:cpt, "99214"]]).annotate.must_equal([:union,
      [:icd9, "412", {:annotation=>{:counts=>{:condition_occurrence=>{}}}}],
      [:cpt, "99214", {:annotation=>{:counts=>{:procedure_occurrence=>{}}}}],
      {:annotation=>{:counts=>{:condition_occurrence=>{}, :procedure_occurrence=>{}}}}
    ])
  end
end
