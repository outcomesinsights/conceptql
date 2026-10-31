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

  let(:ids) { (1..ConceptQL::Scope::CONCEPT_LIST_MIN_ITEMS).to_a }
  # The shape of a gender operator with an "unknown" argument, after an IN
  # list on the same IDs.
  let(:condition) do
    Sequel.expr(race_concept_id: ids) & (Sequel.expr(gender_concept_id: nil) | Sequel.~(gender_concept_id: ids))
  end
  # Sequel's Spark adapter comes with sequel-hexspace, an optional group
  # (BUNDLE_WITH=hexspace). Without it, Sequel.mock(host: :spark) is a plain
  # mock database, which has no WITH. The Rdbms decides the form of the SQL,
  # so the plain mock gets WITH and tests the same thing.
  let(:db) do
    Sequel.mock(host: host).tap do |mock|
      mock.extend_datasets { def supports_cte?(_type = :select) = true } unless mock.dataset.supports_cte?
    end
  end
  let(:dataset) { db[:patients].where(condition) }
  # An operator that evaluates to dataset. Scope#with_ctes reads only these two.
  let(:operator) do
    ds = dataset
    rdbms = ConceptQL::Rdbms.generate(host)
    Object.new.tap do |op|
      op.define_singleton_method(:evaluate) { |_db| ds }
      op.define_singleton_method(:rdbms) { rdbms }
    end
  end
  let(:sql) { ConceptQL::Scope.new.with_ctes(operator, db).sql }
  let(:list_cte) { sql[/(?:"|`)?concept_list_\w+(?:"|`)?(?= AS)/] }
  let(:reads) { "(SELECT #{db.literal(Sequel.identifier(:concept_id))} FROM #{list_cte})" }
  let(:list) { "(#{ids.join(', ')})" }
  let(:where) { sql[/FROM #{Regexp.escape(db.literal(Sequel.identifier(:patients)))} WHERE (.*)/, 1] }

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
