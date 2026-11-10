# frozen_string_literal: true

require_relative "../../../db_helper"
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

  describe "the information types argument" do
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

  # The information types are the concepts of GDM_INFORMATION_TYPE, in the
  # GDM and the OHDSI vocabulary tables alike. The test data has periods of
  # PARTA, PARTB, PARTD, HMO and PARTAB_NOHMO. No concept has the code
  # "PART D" (with a space): the code of Medicare Part D is PARTD.
  describe "against the test data" do
    def periods(*arguments)
      CDB.query([ "information_periods", *arguments ]).query.select_map(:criterion_id).sort
    end

    def warnings(*arguments)
      by_operator(CDB.query([ "information_periods", *arguments ]).warnings)
    end

    def concept_id(code)
      ids = CDB.lexicon.concept_ids(DB, "GDM_INFORMATION_TYPE", [ code ])
      _(ids.size).must_equal 1, "GDM_INFORMATION_TYPE #{code} is not in the lexicon"
      ids.first
    end

    it "selects the periods of a concept code, as its concept ID does" do
      part_d = periods(concept_id("PARTD"))

      _(part_d).wont_be_empty
      _(periods("PARTD")).must_equal part_d
      _(warnings("PARTD")).must_be_empty
    end

    it "takes concept codes and concept IDs together" do
      expected = (periods(concept_id("PARTD")) + periods(concept_id("PARTAB_NOHMO"))).sort

      _(periods("PARTD", concept_id("PARTAB_NOHMO"))).must_equal expected
      _(periods("PARTD", concept_id("PARTAB_NOHMO").to_s)).must_equal expected
    end

    it "warns about an unknown code and does not make it concept ID 0" do
      _(warnings("PART D", "PARTD")).must_equal({ "information_periods" => [ [ "unknown code(s)", "PART D" ] ] })
      _(CDB.query([ "information_periods", "PART D" ]).sql).wont_match(/IN \(0\)/)
      _(periods("PART D")).must_be_empty
      _(periods("PART D", "PARTD")).must_equal periods("PARTD")
    end

    it "compares the case of a code exactly" do
      _(warnings("partd")).must_equal({ "information_periods" => [ [ "unknown code(s)", "partd" ] ] })
      _(periods("partd")).must_be_empty
    end

    it "selects every period without an argument" do
      _(periods.size).must_equal DB[:information_periods].count
    end
  end
end
