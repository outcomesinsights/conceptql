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

CDB = ConceptQL::Database.new(DB)

class Minitest::Spec
  def query(statement)
    CDB.query(statement)
  end
  
  def dataset(statement)
    query(statement).query
  end

  def criteria_ids(statement)
    hash_groups(statement, :criterion_type, :criterion_id)
  end

  def numeric_values(statement)
    hash_groups(statement, :criterion_type, :value_as_number)
  end

  def criteria_counts(statement)
    dataset(statement).from_self.group_and_count(:criterion_type).to_hash(:criterion_type, :count)
  end

  def hash_groups(statement, key, value)
    dataset(statement).from_self.distinct.order(*value).to_hash_groups(key, value)
  end

  def log
    DB.loggers << Logger.new($stdout)
    yield
  ensure
    DB.loggers.clear
  end
end
