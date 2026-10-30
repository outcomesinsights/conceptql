# frozen_string_literal: true

require_relative "../../db_helper"

describe ConceptQL::OneQueryCounts do
  # The Union reads icd9 412 and cpt 99214 with one combined query, so the
  # root query has no CTE for them. icd9 999.99 has no rows.
  let(:empty_code) { %w[icd9 999.99] }
  let(:statement) { [ "union", %w[icd9 412], [ "first", empty_code ], %w[cpt 99214] ] }

  # The SQL statements that the block runs on DB to count rows and people.
  def counting_statements
    sqls = []
    recorder = Object.new
    %i[debug info warn error].each do |level|
      recorder.define_singleton_method(level) { |message| sqls << message }
    end
    DB.loggers << recorder
    yield
    sqls.grep(/count\(DISTINCT/i)
  ensure
    DB.loggers.delete(recorder)
  end

  # The counts of a statement from a query that counts nothing else.
  def own_counts(stmt)
    CDB.query(stmt).query.from_self
       .select_group(:criterion_domain)
       .select_append { Sequel.function(:count, 1).as(:rows) }
       .select_append { count(:person_id).distinct.as(:n) }
       .to_h { |h| [ h.delete(:criterion_domain).to_sym, h ] }
  end

  def counts_of(node)
    node.last[:annotation][:counts]
  end

  def skip_on_spark
    skip "Spark does not run locally" if DB.database_type.to_sym == :spark
  end

  it "counts every operator with one SQL statement" do
    skip_on_spark
    annotated = nil
    statements = counting_statements { annotated = CDB.query(statement).annotate }

    _(statements.length).must_equal(1)
    _(annotated[1..3].map(&:first)).must_equal(%w[icd9 first cpt])
  end

  it "gives each operator the counts of its own query" do
    skip_on_spark
    annotated = CDB.query(statement).annotate
    _, icd9, first, cpt = annotated

    _(counts_of(icd9)[:condition_occurrence][:rows]).must_be :>, 0 # a 0 == 0 match would prove nothing
    _(counts_of(annotated)).must_equal(own_counts(statement))
    _(counts_of(icd9)).must_equal(own_counts(%w[icd9 412]))
    _(counts_of(cpt)).must_equal(own_counts(%w[cpt 99214]))
    _(counts_of(first)).must_equal({ condition_occurrence: { rows: 0, n: 0 } })
  end

  it "reports zeros for an operator with no rows" do
    skip_on_spark
    _(CDB.query(empty_code).query.count).must_equal(0)

    _, _, first = CDB.query(statement).annotate
    empty = first[1]

    _(empty.first).must_equal("icd9")
    _(counts_of(empty)).must_equal({ condition_occurrence: { rows: 0, n: 0 } })
  end

  it "counts each operator with its own query on Spark, which ignores MATERIALIZED" do
    skip_on_spark
    query = CDB.query(statement, database_type: :spark)
    _(query.rdbms).must_be_kind_of(ConceptQL::Rdbms::Spark)

    annotated = nil
    statements = counting_statements { annotated = query.annotate }

    # union, icd9 412, first, icd9 999.99 and cpt 99214
    _(statements.length).must_equal(5)
    _(annotated).must_equal(CDB.query(statement).annotate)
  end

  it "counts nothing with skip_counts" do
    skip_on_spark
    statements = counting_statements { CDB.query(statement).annotate(skip_counts: true) }

    _(statements).must_be_empty
  end
end
