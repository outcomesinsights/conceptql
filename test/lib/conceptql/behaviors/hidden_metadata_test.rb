# frozen_string_literal: true

require_relative "../../../db_helper"

# An operator says that it is hidden, and ConceptQL.metadata leaves out each
# hidden operator. Before, ConceptQL.metadata left out each operator without a
# category. Now every operator has a category (Ryan, 2026-11-03, seed
# conceptql-mdo.4, bead conceptql-voth).
describe "hidden operators" do
  def hidden_names
    %w[count dedup from invalid numeric sum]
  end

  # Each Database builds its own vocabulary operators: a Database with no
  # connection builds them from config/vocabularies.csv, and CDB also builds
  # them from the lexicon of the test database.
  def registries
    %i[gdm gdm_wide].map { |dm| [ "#{dm} without a connection", ConceptQL::Database.new(nil, data_model: dm).operators ] } +
      [ [ "the test database", CDB.operators ] ]
  end

  it "gives every registered operator a category, hidden or not" do
    registries.each do |label, operators|
      # Premise: the registry has vocabulary operators and hidden operators
      _(operators.values.count { |klass| klass <= ConceptQL::Operators::Vocabulary }).must_be :>, 0, label
      _(operators.values.count(&:hidden?)).must_be :>, 0, label

      operators.each do |name, klass|
        _(klass.to_metadata(name)[:categories]).wont_be_empty "#{name} (#{label}) has no category"
      end
    end
  end

  it "gives each category from ConceptQL.categories" do
    known = ConceptQL.categories.map { |cat| [ cat[:name] ] }
    registries.each do |label, operators|
      operators.each do |name, klass|
        _(klass.to_metadata(name)[:categories] - known).must_be_empty "#{name} (#{label})"
      end
    end
  end

  it "hides exactly count, dedup, from, invalid, numeric and sum" do
    registries.each do |label, operators|
      _(operators.select { |_name, klass| klass.hidden? }.keys.sort).must_equal hidden_names, label
    end
  end

  describe "in ConceptQL.metadata" do
    let(:cdb) { ConceptQL::Database.new(nil, data_model: :gdm) }
    let(:published) { ConceptQL.metadata(cdb)[:operators] }

    it "publishes the same 119 operators on gdm as before the hidden flag" do
      _(published.size).must_equal 119
      _(published.keys.sort).must_equal(cdb.operators.keys.sort - hidden_names)
    end

    it "leaves out each hidden operator" do
      _(published.keys & hidden_names).must_be_empty
    end

    it "gives no hidden key" do
      published.each do |name, metadata|
        _(metadata).wont_include :hidden, name
      end
    end
  end

  describe "the hidden macro" do
    let(:operator) { Class.new(ConceptQL::Operators::Operator) }

    it "leaves an operator visible unless the operator says hidden" do
      _(operator).wont_be :hidden?
    end

    it "marks the operator hidden" do
      operator.hidden
      _(operator).must_be :hidden?
    end

    it "does not pass the mark to a subclass" do
      operator.hidden
      _(Class.new(operator)).wont_be :hidden?
    end
  end
end
