require_relative 'db'

$: << "lib"
require 'conceptql'
require 'minitest/spec'
require 'minitest/autorun'

require 'logger'

class Minitest::Spec
  def query(statement)
    ConceptQL::Query.new(DB, statement)
  end
  
  def dataset(statement)
    query(statement).query
  end

  def criteria_ids(statement)
    dataset(statement).from_self.distinct.order(:criterion_id).to_hash_groups(:criterion_type, :criterion_id)
  end

  def criteria_counts(statement)
    dataset(statement).from_self.group_and_count(:criterion_type).to_hash(:criterion_type, :count)
  end

  def log
    DB.loggers << Logger.new($stdout)
    yield
  ensure
    DB.loggers.clear
  end
end
