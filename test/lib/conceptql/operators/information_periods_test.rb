# frozen_string_literal: true

require_relative "../../../helper"
require "conceptql"

describe ConceptQL::Operators::InformationPeriods do
  include SqlMode::CTES

  def assert_information_periods_sql(query, source_table)
    sql = query.sql

    _(sql).must_match(/WITH "information_periods_\d+_1_\w+" AS MATERIALIZED/i)
    _(sql).must_match(/FROM "#{source_table}"/i)
    _(sql).must_match(/FROM \(SELECT \* FROM "information_periods_\d+_1_\w+"\) AS "t1"/i)
  end

  it "should appear for GDM" do
    _(ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm).operators["information_periods"]).must_equal ConceptQL::Operators::InformationPeriods
  end


  it "should produce correct SQL under gdm" do
    cdb = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)

    assert_information_periods_sql(cdb.query([ "information_periods" ]), "information_periods")
  end

  describe "the information type concept ID argument" do
    let(:cdb) { ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm) }

    it "is declared with a meaning" do
      arguments = ConceptQL::Operators::InformationPeriods.to_metadata("information_periods")[:arguments]

      _(arguments.map(&:first)).must_equal [ :information_types ]
      _(arguments.to_h[:information_types][:type]).must_equal :codelist
      _(arguments.to_h[:information_types][:meaning].to_s.strip).wont_be_empty
    end

    it "is optional: a statement without concept IDs validates and filters nothing" do
      query = cdb.query([ "information_periods" ])

      _(query.validation_errors).must_be_empty
      _(query.sql).wont_match(/information_type_concept_id/)
    end

    it "validates a statement with concept IDs and selects only those types" do
      query = cdb.query([ "information_periods", 100000081, "100000082" ])

      _(query.validation_errors).must_be_empty
      _(query.sql).must_match(/"information_type_concept_id" IN \(100000081, 100000082\)/)
    end
  end
end
