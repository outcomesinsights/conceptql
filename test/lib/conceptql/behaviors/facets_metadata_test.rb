# frozen_string_literal: true

require_relative "../../../helper"

# The metadata of each operator has eight facets as top-level keys. The
# values of the first seven come from the code: the upstream validations, the
# behavior modules and the superclasses (bead conceptql-mc54, seed
# conceptql-vox.2). Each operator declares its effects (bead conceptql-x9qv,
# effects_metadata_test.rb). The hidden operators (invalid, sum) are not in
# ConceptQL.metadata, so their facets are read with the same call that
# Nodifier#to_metadata makes for a published operator.
# No database: Database.new(nil) builds the vocabulary operators from
# config/vocabularies.csv.
describe "operator facets in ConceptQL.metadata" do
  let(:cdb) { ConceptQL::Database.new(nil, data_model: :gdm) }

  def facets_of(name)
    cdb.operators.fetch(name).to_metadata(name).slice(*ConceptQL::Metadatable::FACET_KEYS)
  end

  it "lists the facet keys in order" do
    _(ConceptQL::Metadatable::FACET_KEYS).must_equal(%i[upstreams reads_data timeless takes_codes uses_provenance utilization temporal_comparison effects])
  end

  it "gives every published operator every facet key, on both data models" do
    %i[gdm gdm_wide].each do |dm|
      published = ConceptQL.metadata(ConceptQL::Database.new(nil, data_model: dm))[:operators]
      _(published.size).must_equal 119, dm
      published.each do |name, metadata|
        _(ConceptQL::Metadatable::FACET_KEYS - metadata.keys).must_be_empty "#{name} (#{dm})"
      end
    end
  end

  it "serves the facets of a published operator in ConceptQL.metadata" do
    published = ConceptQL.metadata(cdb)[:operators]
    _(published.fetch("before").slice(*ConceptQL::Metadatable::FACET_KEYS)).must_equal(facets_of("before"))
  end

  {
    "before" => { upstreams: "left_right", reads_data: false, timeless: false, takes_codes: false,
                  uses_provenance: false, utilization: false, temporal_comparison: true, effects: %w[keep] },
    "except" => { upstreams: "left_right", reads_data: false, timeless: false, takes_codes: false,
                  uses_provenance: false, utilization: false, temporal_comparison: false, effects: %w[keep] },
    "union" => { upstreams: "two_or_more", reads_data: false, timeless: false, takes_codes: false,
                 uses_provenance: false, utilization: false, temporal_comparison: false, effects: %w[combine] },
    "sum" => { upstreams: "one_or_more", reads_data: false, timeless: false, takes_codes: false,
               uses_provenance: false, utilization: false, temporal_comparison: false, effects: %w[aggregate] },
    "person" => { upstreams: "none_or_one", reads_data: true, timeless: true, takes_codes: false,
                  uses_provenance: false, utilization: false, temporal_comparison: false, effects: %w[select cast] },
    "first" => { upstreams: "one", reads_data: false, timeless: false, takes_codes: false,
                 uses_provenance: false, utilization: false, temporal_comparison: false, effects: %w[keep] },
    "one_in_two_out" => { upstreams: "one", reads_data: false, timeless: false, takes_codes: false,
                          uses_provenance: true, utilization: false, temporal_comparison: false, effects: %w[keep change] },
    "hospice" => { upstreams: "none", reads_data: true, timeless: false, takes_codes: false,
                   uses_provenance: false, utilization: true, temporal_comparison: false, effects: %w[select] },
    "gender" => { upstreams: "none", reads_data: true, timeless: true, takes_codes: false,
                  uses_provenance: false, utilization: false, temporal_comparison: false, effects: %w[select] },
    "ethnicity" => { upstreams: "none", reads_data: true, timeless: true, takes_codes: false,
                     uses_provenance: false, utilization: false, temporal_comparison: false, effects: %w[select] },
    "recall" => { upstreams: "none", reads_data: false, timeless: false, takes_codes: false,
                  uses_provenance: false, utilization: false, temporal_comparison: false, effects: %w[refer] },
    "invalid" => { upstreams: nil, reads_data: false, timeless: false, takes_codes: false,
                   uses_provenance: false, utilization: false, temporal_comparison: false, effects: [] },
    "icd9cm" => { upstreams: "none", reads_data: true, timeless: false, takes_codes: true,
                  uses_provenance: false, utilization: false, temporal_comparison: false, effects: %w[select] }
  }.each do |name, expected|
    it "derives the facets of #{name}" do
      _(facets_of(name)).must_equal(expected)
    end
  end

  # Premise of the icd9cm case: it is a vocabulary operator, built per
  # Database, and a statement names it icd9 (its alias)
  it "reads icd9cm as the vocabulary operator that icd9 names" do
    klass = cdb.operators.fetch("icd9cm")
    _(klass <= ConceptQL::Operators::Vocabulary).must_equal true
    _(klass.aliases).must_include "icd9"
  end
end
