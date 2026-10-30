# frozen_string_literal: true

require_relative "../../db_helper"

# With CONCEPTQL_AVOID_CTES=true, each operator is a subquery and the
# statement has no WITH list of operators (bead conceptql-imv). Until then,
# each operator still read a CTE that the WITH list no longer defined, so the
# database refused the SQL. CI never runs the suite in this mode, so these
# tests run it on the test data.
describe "CONCEPTQL_AVOID_CTES" do
  include SqlMode::AVOID_CTES

  statements = {
    "a recall" => [ "union", [ "recall", "label1" ], [ "one_in_two_out", %w[icd9 412], { label: "label1" } ] ],
    "a timed occurrence" => [ "occurrence", 2, %w[icd9 355.8 401.0 401.9 250.00 780.93 459.81], { at_least: "30d" } ],
    "a co_reported" => [ "co_reported", %w[icd9 412], %w[icd9 412] ],
    "a scope window" => [ "window", [ "after", { left: %w[icd9 412], right: %w[cpt 99214] } ],
                          { window_table: %w[icd9 250.00], adjust_window_start: "-1y" } ]
  }

  def rows(statement)
    CDB.query(statement).query.all.sort_by(&:to_s)
  end

  def rows_with_ctes(statement)
    ENV.delete("CONCEPTQL_AVOID_CTES")
    rows(statement)
  ensure
    ENV["CONCEPTQL_AVOID_CTES"] = "true"
  end

  statements.each do |name, statement|
    it "returns the rows of the default mode for #{name}" do
      expected = rows_with_ctes(statement)

      _(rows(statement)).must_equal expected
    end
  end

  it "returns rows for most of the statements" do
    _(statements.values.count { |statement| rows(statement).any? }).must_be :>=, 3
  end

  it "makes no WITH list" do
    sql = CDB.query([ "after", { left: %w[icd9 412], right: %w[cpt 99214] } ]).sql

    _(sql).wont_include "WITH"
  end

  it "keeps a long concept list as an IN list" do
    ids = (1..ConceptQL::Scope::CONCEPT_LIST_MIN_ITEMS).to_a
    statement = [ "provider_filter", %w[icd9 412], { specialties: ids.join(","), roles: "*" } ]
    sql = CDB.query(statement).query.sql

    _(sql).wont_include "concept_list_"
    _(sql).must_include "IN (#{ids.join(', ')})"
    _(CDB.query(statement).query.all).must_equal []
  end
end
