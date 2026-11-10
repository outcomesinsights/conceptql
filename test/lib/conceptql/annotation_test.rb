# frozen_string_literal: true

require_relative "../../db_helper"

# Counts the operator trees that a Query annotates, while
# Thread.current[:annotated_trees] holds a list.
module AnnotatedTreeRecorder
  def annotate_own_tree(opts)
    Thread.current[:annotated_trees]&.push(opts)
    super
  end
end
ConceptQL::Query.prepend(AnnotatedTreeRecorder)

describe ConceptQL::Annotation do
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

  def annotated_trees
    Thread.current[:annotated_trees] = []
    yield
    Thread.current[:annotated_trees]
  ensure
    Thread.current[:annotated_trees] = nil
  end

  def skip_on_spark
    skip "Spark does not run locally" if DB.database_type.to_sym == :spark
  end

  def annotation(statement, opts = { skip_counts: true })
    ConceptQL::Annotation.new(CDB.query(statement).annotate(opts))
  end

  def ids(annotation)
    annotation.each_operator.map(&:id)
  end

  let(:two_bad_codes) { [ "union", %w[icd9 412 4100], [ "icd9", "250.00", "ZZZ.99" ] ] }

  describe "effective ids" do
    it "generates <operator>-<n> in statement order" do
      _(ids(annotation(two_bad_codes))).must_equal %w[union-1 icd9-1 icd9-2]
    end

    it "keeps a given id, and a generated id avoids it" do
      statement = [ "union", %w[icd9 412], [ "icd9", "250.00", { "id" => "icd9-1" } ], { "id" => "0" } ]

      _(ids(annotation(statement))).must_equal %w[0 icd9-2 icd9-1]
    end

    it "does not change the options of the statement" do
      statement = [ "union", %w[icd9 412], [ "icd9", "250.00", { "id" => "given" } ] ]
      query = CDB.query(statement)
      before = Marshal.load(Marshal.dump(query.statement))
      annotated = query.annotate(skip_counts: true)

      _(query.statement).must_equal before
      _(annotated.last.key?(:id)).must_equal false
      _(annotated.last[:annotation][:id]).must_equal "union-1"
      _(annotated[2].last[:id]).must_equal "given"
    end
  end

  describe "warnings and errors" do
    it "lists the warning of each operator, with its id" do
      ann = annotation(two_bad_codes)
      formatting = ann.warnings.select { |w| w[:message] == "improperly formatted code" }

      _(formatting).must_equal [
        { operator: "icd9", id: "icd9-1", message: "improperly formatted code", details: [ "4100" ] },
        { operator: "icd9", id: "icd9-2", message: "improperly formatted code", details: [ "ZZZ.99" ] }
      ]
      _(ann.errors).must_be_empty
      _(ann.valid?).must_equal true
    end

    it "gives two identical operators two errors with different ids" do
      ann = annotation([ "union", [ "icd9" ], [ "icd9" ] ])

      _(ann.errors).must_equal [
        { operator: "icd9", id: "icd9-1", message: "has no arguments", details: [] },
        { operator: "icd9", id: "icd9-2", message: "has no arguments", details: [] }
      ]
      _(ann.valid?).must_equal false
    end

    it "finds the errors inside the left and right of a binary operator" do
      ann = annotation([ "after", { "left" => [ "icd9" ], "right" => [ "not_an_op", "x" ] } ])

      _(ann.each_operator.map(&:name)).must_equal %w[after icd9 not_an_op]
      _(ann.errors.map { |e| e.values_at(:operator, :id, :message) }).must_equal [
        [ "icd9", "icd9-1", "has no arguments" ],
        [ "not_an_op", "not_an_op-1", "invalid operator" ]
      ]
    end

    it "finds the errors inside the left and right of an invalid operator" do
      ann = annotation([ "not_an_op", { "left" => [ "icd9" ], "right" => %w[icd9 412] } ])

      _(ann.each_operator.map(&:id)).must_equal %w[not_an_op-1 icd9-1 icd9-2]
      _(ann.errors.map { |e| e.values_at(:id, :message) }).must_include [ "icd9-1", "has no arguments" ]
    end

    it "gives the same answer after a JSON round trip" do
      skip_on_spark
      annotated = CDB.query(two_bad_codes).annotate
      ann = ConceptQL::Annotation.new(annotated)
      stored = ConceptQL::Annotation.new(JSON.parse(annotated.to_json))

      _(stored.warnings).must_equal ann.warnings
      _(stored.errors).must_equal ann.errors
      _(stored.each_operator.to_a).must_equal ann.each_operator.to_a
      _(stored.each_operator.first.annotation["counts"]["condition_occurrence"]["rows"]).must_be :>, 0
    end
  end

  # Statements built by hand, to show which values the walk takes as operators
  describe "the walk" do
    def op(name, *items, annotation: {})
      [ name, *items, { "annotation" => annotation } ]
    end

    it "does not take a list of strings as an operator" do
      statement = [ "match", { "left" => %w[icd9 412], "right" => %w[a b], "annotation" => {} } ]

      _(ConceptQL::Annotation.new(statement).each_operator.map(&:name)).must_equal %w[match]
    end

    it "walks the window_table option" do
      table = op("date_range", annotation: { "id" => "date_range-1", "errors" => [ [ "bad date", "x" ] ] })
      statement = [ "icd9", "412", { "window_table" => table, "annotation" => { "id" => "icd9-1" } } ]

      _(ConceptQL::Annotation.new(statement).errors).must_equal [
        { operator: "date_range", id: "date_range-1", message: "bad date", details: [ "x" ] }
      ]
    end
  end

  describe "the annotation cache of a Query" do
    def counts(annotated)
      annotated.last[:annotation][:counts][:condition_occurrence]
    end

    it "gives real counts after a call with skip_counts" do
      skip_on_spark
      query = CDB.query(%w[icd9 412])

      _(counts(query.annotate(skip_counts: true))).must_equal({ rows: 0, n: 0 })
      _(counts(query.annotate)[:rows]).must_be :>, 0
    end

    it "annotates once for repeated calls with the same opts" do
      query = CDB.query(%w[icd9 412])
      first = nil
      trees = annotated_trees do
        first = query.annotate(skip_counts: true)
        _(query.annotate({ skip_counts: true })).must_be_same_as first
      end

      _(trees).must_equal [ { skip_counts: true } ]
    end

    it "gives an invalid operator with a labeled left no false error on a second call" do
      skip_on_spark
      query = CDB.query([ "not_an_op", { "left" => [ "icd9", "412", { "label" => "a" } ], "right" => %w[icd9 413] } ])
      first = query.annotate(skip_counts: true)
      before = Marshal.load(Marshal.dump(first))
      second = ConceptQL::Annotation.new(query.annotate)

      _(second.errors.map { |e| e[:message] }).must_equal [ "invalid operator" ]
      _(first).must_equal before
    end

    it "does not share a result between skip_db and a normal call" do
      query = CDB.query(%w[icd9 000.00])
      no_db = ConceptQL::Annotation.new(query.annotate(skip_db: true))
      with_db = ConceptQL::Annotation.new(query.annotate(skip_counts: true))

      _(no_db.warnings).must_be_empty
      _(with_db.warnings.map { |w| w[:message] }).must_equal [ "unknown code(s)" ]
    end

    it "runs no count SQL for errors, warnings and valid?" do
      skip_on_spark
      query = CDB.query(two_bad_codes)
      result = nil
      statements = counting_statements do
        result = [ query.valid?, query.errors, query.warnings.length ]
      end

      _(statements).must_be_empty
      _(result).must_equal [ true, [], 2 ]
    end

    it "annotates once for errors, warnings and valid?" do
      query = CDB.query([ "union", [ "icd9" ], [ "icd9" ] ])
      trees = annotated_trees do
        _(query.valid?).must_equal false
        _(query.errors.length).must_equal 2
        _(query.warnings).must_be_empty
      end

      _(trees).must_equal [ { skip_counts: true } ]
    end
  end
end
