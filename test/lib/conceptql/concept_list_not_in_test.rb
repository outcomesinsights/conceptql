# frozen_string_literal: true

require_relative "../../helper"

# Scope#with_ctes moves a long IN or NOT IN list (Scope#concept_list?) into a
# CTE. Spark rejects a NOT IN subquery in a nested condition, such as the
# "IS NULL OR NOT IN" of the gender operator: "Null-aware predicate
# sub-queries cannot be used in nested conditions". So on Spark a NOT IN list
# stays a NOT IN list (Rdbms::Generic#supports_nested_not_in_subquery?), and
# an IN list still reads the list CTE.
describe "concept lists in a NOT IN condition" do
  include SqlMode::CTES
  include ConceptListMock

  let(:ids) { (1..ConceptQL::Scope::CONCEPT_LIST_MIN_ITEMS).to_a }
  # The shape of a gender operator with an "unknown" argument, after an IN
  # list on the same IDs.
  let(:condition) do
    Sequel.expr(race_concept_id: ids) & (Sequel.expr(gender_concept_id: nil) | Sequel.~(gender_concept_id: ids))
  end
  let(:table) { :patients }
  let(:dataset) { db[table].where(condition) }
  let(:list) { "(#{ids.join(', ')})" }

  # The number of times item (list or reads) follows op in text. "IN" counts
  # only the IN conditions that are not NOT IN.
  def occurrences(text, op, item)
    text.scan(/#{op == "IN" ? "(?<!NOT)" : ""} #{op} #{Regexp.escape(item)}/).length
  end

  %i[postgres duckdb].each do |each_host|
    describe "on #{each_host}" do
      let(:host) { each_host }

      it "reads the list CTE in the IN and in the NOT IN condition" do
        _(list_cte).wont_be_nil
        _(occurrences(where, "IN", reads)).must_equal(1)
        _(occurrences(where, "NOT IN", reads)).must_equal(1)
        _(occurrences(where, "IN", list)).must_equal(0)
        _(occurrences(where, "NOT IN", list)).must_equal(0)
      end
    end
  end

  describe "on spark" do
    let(:host) { :spark }

    it "keeps the NOT IN list and reads the list CTE in the IN condition" do
      _(list_cte).wont_be_nil
      _(where).wont_include("NOT IN (SELECT")
      _(occurrences(where, "NOT IN", list)).must_equal(1)
      _(occurrences(where, "IN", reads)).must_equal(1)
      _(occurrences(where, "IN", list)).must_equal(0)
    end
  end
end
