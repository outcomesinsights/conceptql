# frozen_string_literal: true

require_relative "../../../helper"

# Each operator declares diagram_base: the symbol that a diagram draws for it
# (bead conceptql-9h85). It replaces an older declaration with the same
# values, whose metadata key bead conceptql-zi43 removed (see
# removed_metadata_keys_test.rb). diagram_base is not a facet.
# No database: Database.new(nil) builds the vocabulary operators from
# config/vocabularies.csv.
describe "diagram_base in ConceptQL.metadata" do
  let(:bases) { %i[selection filter set temporal cast] }

  it "gives every published operator a diagram_base, on both data models" do
    %i[gdm gdm_wide].each do |dm|
      published = ConceptQL.metadata(ConceptQL::Database.new(nil, data_model: dm))[:operators]
      _(published.size).must_equal 119, dm
      published.each do |name, metadata|
        _(bases).must_include metadata[:diagram_base], "#{name} (#{dm})"
      end
    end
  end

  it "gives each hidden operator its diagram_base, and none to invalid" do
    cdb = ConceptQL::Database.new(nil, data_model: :gdm)
    hidden = cdb.operators.select { |_name, klass| klass.hidden? }
    bases_of_hidden = hidden.to_h { |name, klass| [ name, klass.to_metadata(name)[:diagram_base] ] }
    _(bases_of_hidden).must_equal({ "count" => :set, "dedup" => :set, "from" => :selection, "invalid" => nil,
                                    "numeric" => :set, "sum" => :set })
  end

  {
    "icd9cm" => :selection, "cpt_or_hcpcs" => :selection, "hospice" => :selection, "read" => :selection,
    "recall" => :selection, "before" => :filter, "union" => :set, "person" => :cast,
    "episode" => :temporal, "numeric_filter" => :temporal, "time_window" => :temporal
  }.each do |name, base|
    it "draws #{name} as #{base}" do
      metadata = ConceptQL.metadata(ConceptQL::Database.new(nil, data_model: :gdm))[:operators].fetch(name)
      _(metadata[:diagram_base]).must_equal base
    end
  end

  it "is not a facet" do
    _(ConceptQL::Metadatable::FACET_KEYS).wont_include :diagram_base
  end

  it "is declared on the operator class" do
    _(ConceptQL::Operators::Union.diagram_base).must_equal :set
  end
end
