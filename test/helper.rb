require_relative 'db'

if ENV['COVERAGE']
  require 'coverage'
  require 'simplecov'

  ENV.delete('COVERAGE')
  SimpleCov.instance_exec do
    start do
      add_filter "/test/"
      add_group('Missing'){|src| src.covered_percent < 100}
      add_group('Covered'){|src| src.covered_percent == 100}
      yield self if block_given?
    end
  end
end

$: << "lib"
require 'conceptql'
require 'minitest/spec'
require 'minitest/autorun'

require 'logger'
require 'pp'

CDB = ConceptQL::Database.new(DB)
DB.extension :error_sql

class Minitest::Spec
  def annotate(testName, statement)
    load_statement(testName, statement)
    results = query(statement).annotate
    check_output(testName, results)
    return results
  end

  def query(statement)
    CDB.query(statement)
  end

  def dataset(statement)
    statement = query(statement) unless statement.is_a?(ConceptQL::Query)
    statement.query
  end

  def count(testName, statement)
    oad_statement(testName, statement)
    results = dataset(statement).count
    check_output(testName, results)
    return results
  rescue
    puts $!.sql if $!.respond_to?(:sql)
    raise
  end

  def criteria_ids(testName, statement)
    statement = load_statement(testName, statement)
    results = hash_groups(statement, :criterion_domain, :criterion_id)
    check_output(testName, results)
    return results
  end

  # If no statement is passed, this function loads the statement from the specified test
  # file. If a statement is passed, it is written to the file.
  def load_statement(testName, statement=nil)
    statementPath = "test/statements/" + testName
    if statement
      jsonStatement = JSON.generate(statement)
      FileUtils.mkdir_p(File.dirname(statementPath))
      File.open(statementPath, 'w') { |file| file.write(jsonStatement) }
      return statement
    else
      File.open(statementPath, 'r') { |file| statement = file.read }
      return JSON.parse(statement)
    end
  end

  def check_output(testName, results)
    actualOutput = JSON.generate(results)
    expectedOutputPath = "test/results/" + ENV["DATA_MODEL"] + "/" + testName
    if ENV["OVERWRITE_CONCEPTQL_TEST_RESULTS"]
      FileUtils.mkdir_p(File.dirname(expectedOutputPath))
      File.open(expectedOutputPath, 'w') { |file| file.write(actualOutput) }
    else
      File.open(expectedOutputPath, 'r') do |file|
        expectedOutput = file.read
        actualOutput.must_equal(expectedOutput)
      end
    end
  end

  def numeric_values(statement)
    hash_groups(statement, :criterion_domain, :value_as_number)
  end

  def criteria_counts(statement)
    dataset(statement).from_self.group_and_count(:criterion_domain).to_hash(:criterion_domain, :count)
  end

  def hash_groups(statement, key, value)
    dataset(statement).from_self.distinct.order(*value).to_hash_groups(key, value)
  rescue
    puts $!.sql if $!.respond_to?(:sql)
    raise
  end

  def log
    DB.loggers << Logger.new($stdout)
    yield
  ensure
    DB.loggers.clear
  end
end
