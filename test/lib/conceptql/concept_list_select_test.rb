# frozen_string_literal: true

require_relative "../../helper"

# Scope#with_ctes moves a long IN list (Scope#concept_list?) into a CTE in the
# WHERE clause and in the SELECT list (the CASE flags of One In Two Out). Spark
# accepts an IN subquery only in a filter or a join, so on Spark a list in the
# SELECT list stays an IN list (Rdbms::Generic#supports_in_subquery_in_select?).
describe "concept lists in a SELECT list" do
  include SqlMode::CTES
  include ConceptListMock

  let(:ids) { (1..ConceptQL::Scope::CONCEPT_LIST_MIN_ITEMS).to_a }
  let(:in_list) { Sequel.expr(file_provenance_type: ids) }
  let(:table) { :events }
  let(:dataset) do
    db[table].where(in_list).select(:person_id, Sequel.case([ [ in_list, 1 ] ], 0).as(:is_inpatient))
  end
  let(:subquery) { "IN #{reads}" }
  let(:select_list) { sql[/SELECT #{Regexp.escape(quoted(:person_id))}, (.*) FROM #{Regexp.escape(quoted(table))}/, 1] }

  def in_list_count(text)
    text.scan("IN (#{ids.join(', ')})").length
  end

  %i[postgres duckdb].each do |each_host|
    describe "on #{each_host}" do
      let(:host) { each_host }

      it "reads the list CTE in the SELECT list and in the WHERE clause" do
        _(list_cte).wont_be_nil
        _(select_list).must_include(subquery)
        _(where).must_include(subquery)
        _(in_list_count(sql)).must_equal(0)
      end
    end
  end

  describe "on spark" do
    let(:host) { :spark }

    it "keeps an IN list in the SELECT list and reads the list CTE in the WHERE clause" do
      _(list_cte).wont_be_nil
      _(select_list).wont_include("IN (SELECT")
      _(in_list_count(select_list)).must_equal(1)
      _(where).must_include(subquery)
      _(in_list_count(where)).must_equal(0)
    end
  end
end
