# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  # `just test-duckdb` runs at the same time as `just test` in `just ci`, so it
  # writes its report apart from coverage/.
  coverage_dir ENV.fetch("CONCEPTQL_COVERAGE_DIR", "coverage")
  add_filter "/test/"
  enable_coverage :branch
  add_group("Missing") { |src| src.covered_percent < 100 }
  add_group("Covered") { |src| src.covered_percent == 100 }
end

$LOAD_PATH << "lib"
require "conceptql"
ENV["MT_NO_PLUGINS"] = "1" # Work around stupid autoloading of plugins
require "minitest/spec"
require "minitest/mock"
require "minitest/autorun"
require "tempfile"

Minitest::Test.make_my_diffs_pretty!

module Minitest
  class Spec
    if ENV["TESTS_DIV_MOD"]
      div, mod = ENV["TESTS_DIV_MOD"].split(" ", 2).map(&:to_i)
      raise "invalid TESTS_DIV_MOD div: #{div}" unless div >= 2
      raise "invalid TESTS_DIV_MOD mod: #{mod} (div: #{div})" unless mod >= 0 && mod < div

      test_number = -1
      inc = proc { test_number += 1 }

      singleton_class.prepend(Module.new do
        define_method(:it) do |*a, &block|
          return unless inc.call % div == mod

          super(*a, &block)
        end
      end)
    end
  end
end

# The errors or the warnings of a statement (Query#errors, Query#warnings or
# ConceptQL::Annotation) as a hash of operator name => list of
# [message, *details], for short assertions. Two operators with the same name
# share one entry, which keeps the problems of both.
module ProblemsByOperator
  def by_operator(problems)
    problems.each_with_object({}) do |problem, hash|
      (hash[problem[:operator]] ||= []) << [ problem[:message], *problem[:details] ]
    end
  end
end
Minitest::Spec.include(ProblemsByOperator)

# The SQL of a statement depends on CONCEPTQL_AVOID_CTES. A describe block that
# checks the SQL of one mode includes SqlMode::CTES or SqlMode::AVOID_CTES, and
# each of its tests runs in that mode, whatever mode the suite runs in. The
# variable is restored after each test.
module SqlMode
  def self.with(value)
    Module.new do
      define_method(:setup) do
        @sql_mode_saved = ENV.fetch("CONCEPTQL_AVOID_CTES", nil)
        ENV["CONCEPTQL_AVOID_CTES"] = value
        super()
      end

      define_method(:teardown) do
        super()
      ensure
        ENV["CONCEPTQL_AVOID_CTES"] = @sql_mode_saved
      end
    end
  end

  CTES = with(nil)
  AVOID_CTES = with("true")
end

# The SQL that Scope#with_ctes builds for one dataset on a mock database, for
# the tests of concept lists (Scope#concept_list?). A describe block that
# includes ConceptListMock defines host (:postgres, :duckdb or :spark), table
# and dataset (a dataset of db that reads table).
module ConceptListMock
  # Sequel's Spark adapter comes with sequel-hexspace, an optional group
  # (BUNDLE_WITH=hexspace). Without it, Sequel.mock(host: :spark) is a plain
  # mock database, which has no WITH. The Rdbms decides the form of the SQL,
  # so the plain mock gets WITH and tests the same thing.
  WITH_SUPPORT = Module.new do
    def supports_cte?(_type = :select) = true
  end

  def db
    @db ||= Sequel.mock(host: host).tap do |mock|
      mock.extend_datasets(WITH_SUPPORT) unless mock.dataset.supports_cte?
    end
  end

  # An operator that evaluates to dataset. Scope#with_ctes reads only these two.
  def operator
    ds = dataset
    rdbms = ConceptQL::Rdbms.generate(host)
    Object.new.tap do |op|
      op.define_singleton_method(:evaluate) { |_db| ds }
      op.define_singleton_method(:rdbms) { rdbms }
    end
  end

  def sql
    @sql ||= ConceptQL::Scope.new.with_ctes(operator, db).sql
  end

  # The name of the CTE that holds the list.
  def list_cte
    sql[/(?:"|`)?concept_list_\w+(?:"|`)?(?= AS)/]
  end

  # The subquery that reads the list from list_cte.
  def reads
    "(SELECT #{quoted(:concept_id)} FROM #{list_cte})"
  end

  # The WHERE clause of the query.
  def where
    sql[/FROM #{Regexp.escape(quoted(table))} WHERE (.*)/, 1]
  end

  # An identifier as db writes it in SQL.
  def quoted(name)
    db.literal(Sequel.identifier(name))
  end
end

# A test that needs a vocabulary_formats row that the pinned table does not
# have, such as a row that declares case-insensitivity with (?i:...),
# includes FormatsTable and wraps its work in with_formats_table. The rows
# ({ vocabulary_id => regexp }) replace config/vocabulary_formats.tsv for the
# block, and Formats reads the pinned table again afterwards.
module FormatsTable
  def with_formats_table(rows)
    formats = ConceptQL::Vocabularies::Formats
    Tempfile.create([ "vocabulary_formats", ".tsv" ]) do |f|
      f.write("vocabulary_id\tregexp\n")
      rows.each { |id, regexp| f.write("#{id}\t#{regexp}\n") }
      f.flush
      formats.instance_variable_set(:@patterns, nil)
      ConceptQL.stub(:vocabulary_formats_file_path, Pathname.new(f.path)) { yield }
    end
  ensure
    formats.instance_variable_set(:@patterns, nil)
  end
end
