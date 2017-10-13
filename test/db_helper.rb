require_relative "helper"
require_relative "db"

require "logger"
require "pp"
require "fileutils"

CDB = ConceptQL::Database.new(DB, :data_model=>ENV["DATA_MODEL"].to_sym)
DB.extension :error_sql

class Minitest::Spec
  def annotate(test_name, statement=nil)
    load_check(test_name, statement){|stmt| query(stmt).annotate}
  end

  def scope_annotate(test_name, statement=nil)
    load_check(test_name, statement){|stmt| query(stmt).scope_annotate}
  end

  def domains(test_name, statement=nil)
    load_check(test_name, statement){|stmt| query(stmt).domains}
  end

  def results(test_name, statement=nil)
    load_check(test_name, statement){|stmt| dataset(query(stmt)).from_self.order(:person_id, :criterion_table, :criterion_id).all}
  end

  def query(statement)
    CDB.query(statement)
  end

  def dataset(statement)
    statement = query(statement) unless statement.is_a?(ConceptQL::Query)
    statement.query
  end

  def criteria_ids(test_name, statement=nil)
    load_check(test_name, statement){|stmt| hash_groups(stmt, :criterion_domain, :criterion_id)}
  end

  # If no statement is passed, this function loads the statement from the specified test
  # file. If a statement is passed, it is written to the file.
  def load_statement(test_name, statement)
    path = "test/statements/#{test_name}"
    if statement
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, JSON.pretty_generate(statement))
      statement
    else
      JSON.parse(File.read(path))
    end
  end

  def check_output(test_name, results)
    path = "test/results/#{ENV["DATA_MODEL"]}/#{test_name}"

    if ENV["OVERWRITE_CONCEPTQL_TEST_RESULTS"]
      save_results(path, results)
    end

    expected = begin
      File.read(path)
    rescue Errno::ENOENT
      save_results(path, [])
      "[]"
    end

    JSON.parse(results.to_json).must_equal(JSON.parse(expected))
    results
  end

  def save_results(path, results)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, JSON.pretty_generate(results))
  end

  def numeric_values(test_name, statement=nil)
    load_check(test_name, statement){|stmt| hash_groups(stmt, :criterion_domain, :value_as_number)}
  end

  def criteria_counts(test_name, statement=nil)
    load_check(test_name, statement){|stmt| query(stmt).query.from_self.group_and_count(:criterion_domain).order(:criterion_domain).to_hash(:criterion_domain, :count)}
  end

  def optimized_criteria_counts(test_name, statement=nil)
    load_check(test_name, statement){|stmt| query(stmt).optimized.query.from_self.group_and_count(:criterion_domain).order(:criterion_domain).to_hash(:criterion_domain, :count)}
  end

  def hash_groups(statement, key, value)
    dataset(statement).from_self.distinct.order(*value).to_hash_groups(key, value)
  rescue
    puts $!.sql if $!.respond_to?(:sql)
    raise
  end

  def load_check(test_name, statement)
    check_output(test_name, yield(load_statement(test_name, statement)))
  rescue
    puts $!.sql if $!.respond_to?(:sql)
    raise
  end

  def json_fixture(name)
    json_file = Pathname.new("test") + "fixtures" + "json" + (name.to_s + ".json")
    JSON.parse(json_file.read)
  end

  def txt_fixture(name)
    txt_file = Pathname.new("test") + "fixtures" + "txt" + (name.to_s + ".txt")
    txt_file.read
  end

  def log
    DB.loggers << Logger.new($stdout)
    yield
  ensure
    DB.loggers.clear
  end
end

