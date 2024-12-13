# frozen_string_literal: true

require_relative './db_helper'

file_regexps = nil
argv = ARGV.reject { |f| f.start_with?('-') }
file_regexps = argv.map { |f| /#{f}/ } unless argv.empty?

module ConceptQL
  require 'forwardable'
  class StatementTest
    class << self
      def test_from_file(cdb, f)
        f = Pathname.new(f)
        test_type = f.basename.to_s.split('_').first

        case test_type
        when 'crit'
          CriteriaIdsTest.new(cdb, f)
        when 'anno'
          AnnotationTest.new(cdb, f)
        when 'count'
          CriteriaCountsTest.new(cdb, f)
        when 'optcc'
          OptimizedCriteriaCountsTest.new(cdb, f)
        when 'scanno'
          ScopeAnnotationTest.new(cdb, f)
        when 'domains'
          DomainsTest.new(cdb, f)
        when 'num'
          NumericValuesTest.new(cdb, f)
        when 'codes'
          CodeCheckTest.new(cdb, f)
        when 'results'
          ResultsTest.new(cdb, f)
        else
          raise "Invalid operation test prefix: #{test_type}"
        end
      end
    end

    extend Forwardable

    attr_reader :cdb, :statement_file

    def_delegators :cdb, :query

    def initialize(cdb, f)
      @cdb = cdb
      @statement_file = f
    end

    def dataset
      stmt = query(statement) unless statement.is_a?(ConceptQL::Query)
      puts stmt.sql if PRINT_CONCEPTQL
      stmt.query
    end

    def statement
      @statement ||= JSON.parse(File.read(statement_file))
    end

    def each_test(&block)
      load_check(&block)
    end

    def hash_groups(statement, key, value)
      dataset.from_self.distinct.order(key, *value).to_hash_groups(key, value)
    rescue StandardError
      puts $ERROR_INFO.sql if $ERROR_INFO.respond_to?(:sql)
      raise
    end

    def test_name
      @test_name ||= [statement_file.dirname.basename, statement_file.basename]
                     .map(&:to_s)
                     .join('/')
    end

    def check_output(results, has_windows = false)
      path = "test/results/#{cdb.base_data_model}/#{test_name}"

      save_results(path, results) if ENV['CONCEPTQL_OVERWRITE_TEST_RESULTS']

      expected = begin
        File.read(path)
      rescue Errno::ENOENT
        save_results(path, { fail: true })
        '{ "fail": true }'
      end

      message = test_name
      message += ' (with windows)' if has_windows
      message += PP.pp(statement, ''.dup, 10) if PRINT_CONCEPTQL

      yield(results, expected, test_name, message)
      results
    end

    def save_results(path, results)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, JSON.pretty_generate(results))
    end

    def load_check(&block)
      # Check without scope windows
      check_output(result_to_check(statement, false), false, &block)

      # Check with scope windows, unless the test is already a scope window test
      unless statement.first == 'window'
        sw_statement = ['window', statement,
                        { 'window_table' => ['date_range', { 'start' => '1900-01-01', 'end' => '2100-12-31' }] }]
        check_output(result_to_check(statement, true), true, &block)

        sw_statement = ['window', statement, { 'start_date' => '1900-01-01', 'end_date' => '2100-12-31' }]
        check_output(result_to_check(statement, true), true, &block)
      end

      unless SKIP_SQL_GENERATION_TEST
        begin
          query(statement).sql(:create_tables)
          query(['window', statement,
                 { 'window_table' => ['date_range', { 'start' => '1900-01-01', 'end' => '2100-12-31' }] }]).sql(:create_tables)
          query(['window', statement,
                 { 'start_date' => '1900-01-01', 'end_date' => '2100-12-31' }]).sql(:create_tables)
        rescue ConceptQL::Query::QueryError
          # Suppress this new issue
        end
      end

      if PERFORMANCE_TEST_TIMES.positive?
        times = PERFORMANCE_TEST_TIMES.times.map do
          before = clock_time
          yield(statement, false)
          clock_time - before
        end
        avg_time = times.sum / times.length

        path = "test/performance/#{CDB.base_data_model}/#{test_name.sub(/\.json\z/, '.csv')}"
        sha1 = `git rev-parse HEAD`.chomp
        adapter = "#{DB.adapter_scheme}/#{DB.database_type}"

        FileUtils.mkdir_p(File.dirname(path))
        File.open(path, 'ab') do |file|
          file.puts([sha1, adapter, DB.opts[:database], Time.now, avg_time].join(','))
        end
      end
    rescue StandardError
      puts $ERROR_INFO.sql if $ERROR_INFO.respond_to?(:sql)
      raise
    end
  end

  class AnnotationTest < StatementTest
    def result_to_check(stmt, remove_window)
      query(stmt).annotate
    end
  end

  class ScopeAnnotationTest < StatementTest
    def result_to_check(stmt, remove_window)
      query(stmt).scope_annotate
    end
  end

  class DomainsTest < StatementTest
    def result_to_check(stmt, remove_window)
      query(stmt).domains
    end
  end

  class CriteriaIdsTest < StatementTest
    def result_to_check(stmt, remove_window)
      hash_groups(stmt, :criterion_domain, :criterion_id)
    end
  end

  class CodeCheckTest < StatementTest
    def result_to_check(stmt, remove_window)
      query(stmt).code_list.map(&:to_s)
    end
  end

  class NumericValuesTest < StatementTest
    def result_to_check(stmt, remove_window)
      hash_groups(stmt, :criterion_domain, :value_as_number)
    end
  end

  class CriteriaCountsTest < StatementTest
    def result_to_check(stmt, remove_window)
      cq = query(stmt)
      puts cq.sql if PRINT_CONCEPTQL
      cq.query.from_self.group_and_count(:criterion_domain).order(:criterion_domain).to_hash(:criterion_domain, :count)
    end
  end

  class OptimizedCriteriaCountsTest < StatementTest
    def result_to_check(stmt, remove_window)
      cq = query(stmt).optimized
      puts cq.sql if PRINT_CONCEPTQL
      cq.query.from_self.group_and_count(:criterion_domain).order(:criterion_domain).to_hash(:criterion_domain, :count)
    end
  end

  class ResultsTest < StatementTest
    def result_to_check(stmt, remove_window)
      ds = dataset.from_self

      if cdb.data_model.data_model == :gdm_wide
        cols = ds.columns
        if cols.include?(:criterion_table)
          ds = ds.select(*(cols - [:criterion_table]))
                 .select_append(
                   Sequel.case({ 'observations' => 'clinical_codes' }, :criterion_table,
                               :criterion_table).as(:criterion_table)
                 )
                 .from_self
                 .select(*cols) # Preserve the original column order
                 .from_self
        end
        if cols.include?(:uuid)
          ds = ds.select(*(cols - [:uuid]))
                 .select_append(
                   Sequel.function(:regexp_replace, :uuid, 'observations', 'clinical_codes').as(:uuid)
                 )
                 .from_self
                 .select(*cols) # Preserve the original column order
                 .from_self
        end
      end

      order_columns = %i[person_id criterion_table criterion_domain start_date criterion_id]
      order_columns << :uuid if ds.columns.include?(:uuid)
      order_columns << :window_id if ds.columns.include?(:window_id)
      ds = ds.order(*order_columns)
      ds = ds.select_remove(:window_id) if remove_window

      ds.all
      # results = ds.all
      # results.each do |h|
      #  h.transform_values! { |v| v.is_a?(Time) || v.is_a?(DateTime) ? v.to_date : v }
      # end
    end
  end
end

def clock_time
  Process.clock_gettime(Process::CLOCK_MONOTONIC)
end

PERFORMANCE_TEST_TIMES = ENV['CONCEPTQL_PERFORMANCE_TEST_TIMES'].to_i
SKIP_SQL_GENERATION_TEST = ENV['CONCEPTQL_SKIP_SQL_GENERATION_TEST']

def my_time_it(name)
  start_time = Time.now
  yield
  return unless ENV['CONCEPTQL_TIME_IT']

  end_time = Time.now
  CSV.open('/tmp/conceptql_times.csv', 'a') do |csv|
    csv << [name, start_time, end_time, end_time - start_time]
  end
end

file_tests = Pathname.glob('./test/statements/**/*').reject do |f|
  f.directory? || (file_regexps.present? && file_regexps.none? { |r| f.to_s =~ r })
end.map { |f| ConceptQL::StatementTest.test_from_file(CDB, f) }
describe ConceptQL::Operators do
  file_tests.each do |file_test|
    it "should produce correct results for #{file_test.test_name}" do
      file_test.each_test do |results, expected, name, message|
        my_time_it([name, message].join(' -- ')) do
          results = results.all if results.respond_to?(:all)
          _(JSON.parse(results.to_json)).must_equal(JSON.parse(expected), message)
        end
      end
    end
  end
end
