require_relative "helper"
require_relative "db"

require "fileutils"
require "logger"
require "pp"
require "shell"

ENV["CONCEPTQL_DATA_MODEL"] ||= ConceptQL::DEFAULT_DATA_MODEL.to_s

CDB = ConceptQL::Database.new(DB, :data_model=>ENV["CONCEPTQL_DATA_MODEL"].to_sym)
CDB.dm.nschema.remake_views!(DB)
DB.extension :error_sql
DB.logger = ConceptQL.logger

PRINT_CONCEPTQL = ENV["CONCEPTQL_PRINT_SQL"]

ENV["CONCEPTQL_IN_TEST_MODE"] = "I'm so sorry I did this"
if ENV["CONCEPTQL_OVERWRITE_TEST_RESULTS"]
  puts "You're sure you want to overwrite test results?"
  exit 1 unless STDIN.gets.chomp == "yes"
end

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
    load_check(test_name, statement) do |stmt, remove_window|
      q = query(stmt)
      ds = dataset(q).from_self

      order_columns = [:person_id, :criterion_table, :criterion_domain, :start_date, :criterion_id]
      order_columns << :uuid if q.include_column?(:uuid)
      order_columns << :window_id if q.include_column?(:window_id)
      ds = ds.order(*order_columns)

      results = ds.all
      results.each do |h|
        h.transform_values! { |v| v.is_a?(Time) || v.is_a?(DateTime) ? v.to_date : v }
        h.delete(:window_id) if remove_window
        h
      end
    end
  end

  def query(statement)
    CDB.query(statement)
  end

  def dataset(statement)
    statement = query(statement) unless statement.is_a?(ConceptQL::Query)
    puts statement.sql(:formatted) if PRINT_CONCEPTQL
    statement.query
  end

  def criteria_ids(test_name, statement=nil)
    load_check(test_name, statement) do |stmt|
      hash_groups(stmt, :criterion_domain, :criterion_id)
    end
  end

  def code_check(test_name, statement=nil)
    load_check(test_name, statement){|stmt| query(stmt).code_list.map(&:to_s)}
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

  def check_output(test_name, results, statement, has_windows = false)
    path = "test/results/#{ENV["CONCEPTQL_DATA_MODEL"]}/#{test_name}"

    # This removes the Projection operator that we've secretly
    # inserted into every statement
    if results.is_a?(Array) && results.first.to_s == "projection"
      results = results[1]
    end
    if ENV["CONCEPTQL_OVERWRITE_TEST_RESULTS"]
      save_results(path, results)
    end

    expected = begin
      File.read(path)
    rescue Errno::ENOENT
      save_results(path, { fail: true })
      '{ "fail": true }'
    end

    message = test_name
    message += " (with windows)" if has_windows
    message += PP.pp(statement, "".dup, 10) if PRINT_CONCEPTQL

    _(JSON.parse(results.to_json)).must_equal(JSON.parse(expected), message)
    results
  end

  def save_results(path, results)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, JSON.pretty_generate(results))
  end

  def numeric_values(test_name, statement=nil)
    load_check(test_name, statement){|stmt| hash_groups(stmt, :criterion_domain, :lab_value_as_number)}
  end

  def criteria_counts(test_name, statement=nil)
    load_check(test_name, statement) do |stmt|
      cq = query(stmt)
      puts cq.sql(:formatted) if PRINT_CONCEPTQL
      cq.query.from_self.group_and_count(:criterion_domain).order(:criterion_domain).to_hash(:criterion_domain, :count)
    end
  end

  def optimized_criteria_counts(test_name, statement=nil)
    load_check(test_name, statement) do |stmt|
      cq = query(stmt).optimized
      puts cq.sql(:formatted) if PRINT_CONCEPTQL
      cq.query.from_self.group_and_count(:criterion_domain).order(:criterion_domain).to_hash(:criterion_domain, :count)
    end
  end

  def hash_groups(statement, key, value)
    dataset(statement).from_self.distinct.order(key, *value).to_hash_groups(key, value)
  end

  def clock_time
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  PERFORMANCE_TEST_TIMES = ENV["CONCEPTQL_PERFORMANCE_TEST_TIMES"].to_i
  SKIP_SQL_GENERATION_TEST = ENV["CONCEPTQL_SKIP_SQL_GENERATION_TEST"]
  def load_check(test_name, statement)
    if test_name =~ /requires_lexicon/i && ENV["LEXICON_URL"].nil?
      skip
      return
    end
    statement = load_statement(test_name, statement)

    # Check without scope windows
    results = yield(statement, false)
    check_output(test_name, results, statement, false)

    # Check with scope windows, unless the test is already a scope window test
    unless statement.first == 'window'
      sw_statement = ["window", statement, {'window_table' => [ 'date_range', { 'start' => '1900-01-01', 'end' => '2100-12-31' } ] } ]
      results = yield(sw_statement, true)
      check_output(test_name, results, statement, true)

      sw_statement = ["window", statement, { 'start_date' => '1900-01-01', 'end_date' => '2100-12-31' } ]
      results = yield(sw_statement, true)
      check_output(test_name, results, statement, true)
    end

    unless SKIP_SQL_GENERATION_TEST
      begin
        query(statement).sql(:create_tables)
        query(["window", statement, {'window_table' => [ 'date_range', { 'start' => '1900-01-01', 'end' => '2100-12-31' } ] } ]).sql(:create_tables)
        query(["window", statement, { 'start_date' => '1900-01-01', 'end_date' => '2100-12-31' } ]).sql(:create_tables)
      rescue ConceptQL::Query::QueryError
        # Suppress this new issue
      end
    end

    if PERFORMANCE_TEST_TIMES > 0
      times = PERFORMANCE_TEST_TIMES.times.map do
        before = clock_time
        yield(statement, false)
        clock_time - before
      end
      avg_time = times.sum/times.length

      path = "test/performance/#{ENV["CONCEPTQL_DATA_MODEL"]}/#{test_name.sub(/\.json\z/, '.csv')}"
      sha1 = `git rev-parse HEAD`.chomp
      adapter = "#{DB.adapter_scheme}/#{DB.database_type}"

      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, 'ab') do |file|
        file.puts([sha1, adapter, DB.opts[:database], Time.now, avg_time].join(','))
      end
    end
  rescue
    if $!.respond_to?(:sql) 
      sql = ConceptQL::SqlFormatters.format($!.sql, timeout: 10)
      puts sql
      if ENV["CONCEPTQL_STOP_ON_ERROR"]
        file = "/tmp/error.sql"
        File.write(file, sql)
        url = Sequelizer.options[:url]
        cmd = if DB.database_type == :sqlite
                url = url.sub("sqlite://", "")
                :sqlite3
              else
                :psql
              end
        Shell.def_system_command(cmd)
        sh = Shell.new
        sh.out do
          cat(file) | send(cmd, url)
        end
      end
    end
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

