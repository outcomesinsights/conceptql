# frozen_string_literal: true

require_relative "../../../helper"
require "conceptql/rdbms/spark"

# Match compares its key columns with = and every other column NULL-safe, so a
# stream matched with itself keeps every record (bead conceptql-of2). With
# join_columns it compares only the person and the listed columns.
# No live database: the mock never answers a query.
describe ConceptQL::Operators::Match do
  let(:cdb) { ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm_wide) }
  let(:icd) { [ "icd9", "412", { uuid: true } ] }

  def errors_for(statement)
    cdb.query(statement).annotate.last[:annotation][:errors]
  end

  # The WHERE clause of the EXISTS subquery that compares l to r
  def join_check(statement)
    cdb.query(statement).sql[/AS "r" WHERE (.*?)\)\)\) AS "t1"\) SELECT/, 1]
  end

  it "compares key columns with = and the other columns NULL-safe" do
    check = join_check([ "match", { left: icd, right: icd } ])

    _(check).must_include '("l"."person_id" = "r"."person_id")'
    _(check).must_include '("l"."uuid" = "r"."uuid")'
    _(check).must_include '("l"."label" IS NOT DISTINCT FROM "r"."label")'
    _(check).must_include '("l"."end_date" IS NOT DISTINCT FROM "r"."end_date")'
    _(check).wont_include '("l"."label" = "r"."label")'
  end

  it "compares only the person and the join_columns" do
    check = join_check([ "match", { left: icd, right: icd, join_columns: [ "uuid" ] } ])

    _(check).must_equal '(("l"."person_id" = "r"."person_id") AND ("l"."uuid" = "r"."uuid"))'
  end

  it "keeps = for only_columns that are key columns" do
    check = join_check([ "match", { left: icd, right: icd, only_columns: [ "uuid" ] } ])

    _(check).must_equal '("l"."uuid" = "r"."uuid")'
  end

  it "rejects join_columns next to only_columns or except_columns" do
    statement = [ "match", { left: icd, right: icd, join_columns: [ "uuid" ], only_columns: [ "uuid" ], except_columns: [ "label" ] } ]

    _(errors_for(statement)).must_equal [ [ "conflicting options", "join_columns", "only_columns", "except_columns" ] ]
  end

  it "accepts join_columns alone" do
    _(errors_for([ "match", { left: icd, right: icd, join_columns: [ "uuid" ] } ])).must_be_nil
  end

  # Each CTE name ends in a counter and a random hex suffix
  def masked_sql(statement)
    cdb.query(statement).sql.gsub(/_\d+_\h{32}\b/, "_N_HEX")
  end

  def match_with(opts)
    [ "match", { left: icd, right: icd }.merge(opts) ]
  end

  # Existing statements give invert_match as the string "true". A caller can
  # also give true or false (bead conceptql-zq2).
  describe "invert_match" do
    it "inverts the match for true and \"true\"" do
      _(masked_sql(match_with({}))).wont_include "WHERE NOT (EXISTS"
      _(masked_sql(match_with(invert_match: true))).must_include "WHERE NOT (EXISTS"
      _(masked_sql(match_with(invert_match: "true"))).must_equal masked_sql(match_with(invert_match: true))
    end

    [ false, nil, "", "false", "FALSE", " False " ].each do |value|
      it "does not invert the match for #{value.inspect}" do
        _(masked_sql(match_with(invert_match: value))).must_equal masked_sql(match_with({}))
      end
    end
  end

  # A column list can be one comma-separated string
  describe "column lists as comma-separated strings" do
    it "gives the same SQL for only_columns as a string and as an array" do
      _(masked_sql(match_with(only_columns: "uuid, start_date"))).must_equal masked_sql(match_with(only_columns: %w[uuid start_date]))
    end

    it "gives the same SQL for except_columns as a string and as an array" do
      _(masked_sql(match_with(except_columns: "label,end_date"))).must_equal masked_sql(match_with(except_columns: %w[label end_date]))
    end

    it "gives the same SQL for join_columns as a string and as an array" do
      _(masked_sql(match_with(join_columns: " uuid "))).must_equal masked_sql(match_with(join_columns: [ "uuid" ]))
    end

    it "treats a blank join_columns as unset" do
      _(masked_sql(match_with(join_columns: " "))).must_equal masked_sql(match_with({}))
      _(errors_for(match_with(join_columns: "", only_columns: [ "uuid" ]))).must_be_nil
    end

    it "rejects a join_columns string next to an only_columns string" do
      _(errors_for(match_with(join_columns: "uuid", only_columns: "uuid"))).must_equal [ [ "conflicting options", "join_columns", "only_columns" ] ]
    end
  end

  describe "#null_safe_equal" do
    let(:db) { Sequel.mock(host: :postgres) }

    it "is IS NOT DISTINCT FROM by default" do
      _(db.literal(ConceptQL::Rdbms::Generic.new.null_safe_equal(:a, :b))).must_equal '("a" IS NOT DISTINCT FROM "b")'
    end

    it "is <=> on Spark" do
      _(db.literal(ConceptQL::Rdbms::Spark.new.null_safe_equal(:a, :b))).must_equal '("a" <=> "b")'
    end
  end
end
