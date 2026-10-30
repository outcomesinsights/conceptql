# frozen_string_literal: true

require_relative "../../db_helper"

# Scope sends each IN list of at least CONCEPT_LIST_MIN_ITEMS integers once,
# as a CTE (Scope#concept_list_condition). The statement suite checks that the
# rows do not change. This checks the form of the SQL on each database.
describe "concept lists" do
  # Both specialty columns read the same list of CONCEPT_LIST_MIN_ITEMS IDs.
  let(:ids) { (1..ConceptQL::Scope::CONCEPT_LIST_MIN_ITEMS).to_a }
  let(:statement) { [ "provider_filter", %w[icd9 412], { specialties: ids.join(","), roles: "*" } ] }
  let(:sql) { CDB.query(statement).query.sql }

  it "puts a long list in one CTE, which both columns read" do
    lists = sql.scan(/("concept_list_\w+"|`concept_list_\w+`) AS/).flatten

    _(lists.length).must_equal(1)
    _(sql.scan("IN (SELECT #{DB.literal(Sequel.identifier(:concept_id))} FROM #{lists.first})").length).must_equal(2)
  end

  it "materializes the list where the database supports it" do
    materialized = CDB.query(statement).rdbms.supports_materialized?

    _(sql.match?(/concept_list_\w+.? AS MATERIALIZED \(SELECT \* FROM \(VALUES/)).must_equal(materialized)
  end
end
