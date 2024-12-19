# frozen_string_literal: true

require_relative './db_helper'
require_relative './statement_tests'

file_regexps = nil
argv = ARGV.reject { |f| f.start_with?('-') }
file_regexps = argv.map { |f| /#{f}/ } unless argv.empty?

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

describe ConceptQL::Operators do
  ConceptQL::StatementFileTest.all(CDB, file_regexps).each do |file_test|
    it "should produce correct results for #{file_test.test_name}" do
      file_test.each_test do |results|
        my_time_it(results.message) do
          debugger if JSON.parse(results.fetch.to_json) != JSON.parse(results.expected)
          _(JSON.parse(results.fetch.to_json)).must_equal(JSON.parse(results.expected), results.message)
        end
      end
    end
  end
end
