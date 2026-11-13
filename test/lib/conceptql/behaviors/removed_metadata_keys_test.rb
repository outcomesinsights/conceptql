# frozen_string_literal: true

require_relative "../../../helper"

# Bead conceptql-zi43 removed four keys from the operator metadata. The
# upstreams facet replaces min_upstreams and max_upstreams, and diagram_base
# replaces basic_type and arity (arity was a number made from basic_type).
# This file is the only test that names them.
# No database: Database.new(nil) builds the vocabulary operators from
# config/vocabularies.csv.
describe "the removed keys of ConceptQL.metadata" do
  let(:removed) { %i[basic_type arity min_upstreams max_upstreams] }

  it "are in no published operator, on both data models" do
    %i[gdm gdm_wide].each do |dm|
      published = ConceptQL.metadata(ConceptQL::Database.new(nil, data_model: dm))[:operators]
      _(published.size).must_equal 119, dm
      published.each do |name, metadata|
        _(metadata.keys & removed).must_be_empty "#{name} (#{dm})"
        _(metadata.keys).must_include :upstreams
        _(metadata.keys).must_include :diagram_base
      end
    end
  end

  it "are in no hidden operator" do
    cdb = ConceptQL::Database.new(nil, data_model: :gdm)
    hidden = cdb.operators.select { |_name, klass| klass.hidden? }
    _(hidden.keys.sort).must_equal %w[count dedup from invalid numeric sum]
    hidden.each do |name, klass|
      _(klass.to_metadata(name).keys & removed).must_be_empty name
    end
  end

  it "have no methods left on the operator classes" do
    %i[basic_type arity allows_one_upstream allows_many_upstreams].each do |meth|
      _(ConceptQL::Operators::Union).wont_respond_to meth
      _(ConceptQL::Operators::Person).wont_respond_to meth
    end
  end
end
