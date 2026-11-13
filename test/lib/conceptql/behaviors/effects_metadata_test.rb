# frozen_string_literal: true

require_relative "../../../helper"

# Each operator declares its effects on rows with the effects macro of
# Metadatable (bead conceptql-x9qv, seed conceptql-vox.2). A subclass
# inherits them, so the vocabulary operators get select from Vocabulary.
# No database: Database.new(nil) builds the vocabulary operators from
# config/vocabularies.csv.
describe "operator effects in ConceptQL.metadata" do
  # The declarations that Ryan approved, operator by operator, in the order
  # that each operator declares them
  table = {
    "cpt_or_hcpcs" => %w[select], "date_range" => %w[select], "from" => %w[select],
    "gender" => %w[select], "race" => %w[select], "ethnicity" => %w[select],
    "hospice" => %w[select], "hospitalization" => %w[select], "snf" => %w[select],
    "information_periods" => %w[select],
    "place_of_service_filter" => %w[keep], "provenance" => %w[keep], "numeric_filter" => %w[keep],
    "first" => %w[keep], "last" => %w[keep], "occurrence" => %w[keep], "dedup" => %w[keep],
    "filter" => %w[keep], "except" => %w[keep], "match" => %w[keep], "person_filter" => %w[keep],
    "before" => %w[keep], "after" => %w[keep], "during" => %w[keep], "contains" => %w[keep],
    "any_overlap" => %w[keep], "equal" => %w[keep],
    "provider_filter" => %w[keep change],
    "time_window" => %w[change],
    "numeric" => %w[select change],
    "trim_date_start" => %w[keep change], "trim_date_end" => %w[keep change], "one_in_two_out" => %w[keep change],
    "union" => %w[combine],
    "co_reported" => %w[combine keep],
    "count" => %w[aggregate], "sum" => %w[aggregate], "episode" => %w[aggregate],
    "person" => %w[select cast], "death" => %w[select cast],
    "recall" => %w[refer],
    "invalid" => []
  }

  known = %w[select keep change combine aggregate cast refer].freeze

  def operators(data_model)
    ConceptQL::Database.new(nil, data_model: data_model).operators
  end

  def vocabulary?(klass)
    klass <= ConceptQL::Operators::Vocabulary
  end

  it "lists the seven effects in order" do
    _(ConceptQL::Metadatable::EFFECTS.map(&:to_s)).must_equal known
  end

  it "puts effects last in FACET_KEYS" do
    _(ConceptQL::Metadatable::FACET_KEYS.last).must_equal :effects
  end

  %i[gdm gdm_wide].each do |dm|
    it "gives every published operator at least one known effect (#{dm})" do
      published = ConceptQL.metadata(ConceptQL::Database.new(nil, data_model: dm))[:operators]
      _(published.size).must_equal 119
      published.each do |name, metadata|
        _(metadata.fetch(:effects)).wont_be_empty "#{name} (#{dm})"
        _(metadata[:effects] - known).must_be_empty "#{name} (#{dm})"
      end
    end

    it "gives every operator, hidden or not, known effects, and only invalid none (#{dm})" do
      ops = operators(dm)
      _(ops.size).must_equal 125
      ops.each do |name, klass|
        effects = klass.to_metadata(name)[:effects]
        _(effects - known).must_be_empty "#{name} (#{dm})"
        _(effects.empty?).must_equal(name == "invalid", "#{name} (#{dm})")
      end
    end

    it "pins the declaration of every operator that is not a vocabulary operator (#{dm})" do
      static = operators(dm).reject { |_name, klass| vocabulary?(klass) }
      _(static.keys.sort).must_equal table.keys.sort
      _(static.to_h { |name, klass| [ name, klass.to_metadata(name)[:effects] ] }).must_equal(table)
    end

    it "gives every vocabulary operator the effects of Vocabulary (#{dm})" do
      vocab = operators(dm).select { |_name, klass| vocabulary?(klass) }
      _(vocab.size).must_equal 83
      _(vocab.to_h { |name, klass| [ name, klass.to_metadata(name)[:effects] ] }.values.uniq).must_equal [ %w[select] ]
    end
  end

  it "declares select on Vocabulary itself" do
    _(ConceptQL::Operators::Vocabulary.effects).must_equal [ :select ]
  end

  it "raises when a class declares an unknown effect" do
    error = _ { Class.new(ConceptQL::Operators::Operator) { effects :keep, :explode } }
            .must_raise ConceptQL::Metadatable::UnknownEffectError
    _(error.message).must_include "[:explode]"
  end

  it "lets a subclass replace the effects that it inherits" do
    parent = Class.new(ConceptQL::Operators::Operator) { effects :keep }
    child = Class.new(parent) { effects :change }
    _(child.effects).must_equal [ :change ]
    _(parent.effects).must_equal [ :keep ]
  end
end
