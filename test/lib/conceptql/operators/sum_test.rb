# frozen_string_literal: true

require_relative "../../../helper"

# Ryan ruled on 2026-10-30 (seed conceptql-6c3) that sum gets a boolean
# option group_by_person. Without it, sum groups by every column except the
# dates, criterion_id and value_as_number, so one person can get several rows
# (one per source_value, criterion_table and criterion_domain). With it, sum
# gives one person result per person. The live totals are in
# sum_group_by_person_test.rb. No live database here: the mock never answers
# a query.
describe ConceptQL::Operators::Sum do
  let(:cdb) { ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm) }
  let(:stream) { [ "numeric", 1, [ "icd9", "412" ] ] }

  def masked_sql(statement)
    cdb.query(statement).sql.gsub(/_\d+_\d+_\h{32}/, "_CTE")
  end

  def errors_for(statement)
    by_operator(cdb.query(statement).errors)
  end

  def warnings_for(statement)
    by_operator(cdb.query(statement).warnings)
  end

  # The SQL of the outermost SELECT of sum, the one with the GROUP BY.
  def group_by_clause(statement)
    masked_sql(statement)[/GROUP BY [^)]*/]
  end

  describe "without group_by_person" do
    it "groups by every column except the dates, criterion_id and value_as_number" do
      _(group_by_clause([ "sum", stream ]))
        .must_equal 'GROUP BY "person_id", "criterion_table", "criterion_domain", ' \
                    '"source_value", "source_vocabulary_id", "label", "column_family"'
    end

    it "gives the same SQL with group_by_person false" do
      _(masked_sql([ "sum", stream, { "group_by_person" => false } ])).must_equal masked_sql([ "sum", stream ])
    end

    it "keeps the domains of its upstreams" do
      _(cdb.query([ "sum", stream ]).domains).must_equal [ :condition_occurrence ]
    end
  end

  describe "with group_by_person" do
    let(:statement) { [ "sum", stream, { "group_by_person" => true } ] }

    it "groups by person_id only" do
      _(group_by_clause(statement)).must_equal 'GROUP BY "person_id"'
    end

    it "groups by person_id and window_id in a window table" do
      windowed = [ "window", statement, { "window_table" => [ "date_range", { "start" => "2000-01-01", "end" => "2010-12-31" } ] } ]
      _(masked_sql(windowed)).must_include 'GROUP BY "person_id", "window_id"'
    end

    it "labels each result as the person cast does, with criterion_id 0" do
      sql = masked_sql(statement)
      _(sql).must_include "0 AS \"criterion_id\""
      _(sql).must_include "CAST('patients' AS text) AS \"criterion_table\""
      _(sql).must_include "CAST('person' AS text) AS \"criterion_domain\""
      _(sql).must_include "CAST('default' AS text) AS \"column_family\""
    end

    it "takes the earliest start_date, the latest end_date and the sum of value_as_number" do
      sql = masked_sql(statement)
      _(sql).must_include 'min("start_date") AS "start_date"'
      _(sql).must_include 'max("end_date") AS "end_date"'
      _(sql).must_include 'sum("value_as_number") AS "value_as_number"'
    end

    it "sets the other columns to NULL" do
      sql = masked_sql([ "sum", [ "numeric", 1, [ "loinc", "2160-0" ] ], { "group_by_person" => true } ])
      %w[source_value source_vocabulary_id label value_as_string].each do |column|
        _(sql).must_include "CAST(NULL AS text) AS \"#{column}\""
      end
      _(sql).must_include 'CAST(NULL AS Bigint) AS "value_as_concept_id"'
    end

    it "has the person domain" do
      _(cdb.query(statement).domains).must_equal [ :person ]
      _(cdb.query([ "sum", [ "icd9", "412" ], [ "cpt", "99214" ], { "group_by_person" => true } ]).domains)
        .must_equal [ :person ]
    end

    it "gives one result per person" do
      _(cdb.query(statement).events_per_patient).must_equal :single
      _(cdb.query([ "sum", stream ]).events_per_patient).must_equal :multiple
    end

    it "is valid" do
      _(errors_for(statement)).must_be_empty
      _(warnings_for(statement)).must_be_empty
    end
  end

  it "rejects a group_by_person that is not true or false" do
    _(errors_for([ "sum", stream, { "group_by_person" => "yes" } ]))
      .must_equal({ "sum" => [ [ "wrong option format", "group_by_person", "yes" ] ] })
  end

  it "accepts a group_by_person without a value, as an editor can send it" do
    _(errors_for([ "sum", stream, { "group_by_person" => nil } ])).must_be_empty
  end

  # sum is hidden, so ConceptQL.metadata leaves it out. Ask the class.
  it "declares group_by_person in its metadata, so an editor can show it" do
    option = cdb.operators(:gdm).fetch("sum").to_metadata("sum")[:options][:group_by_person]
    _(option[:type]).must_equal :boolean
    _(option[:label]).must_equal "Group By Person"
    _(option[:instructions]).wont_be_empty
  end
end
