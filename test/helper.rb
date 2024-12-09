# frozen_string_literal: true

# if ENV['COVERAGE']
#  require 'coverage'
#  require 'simplecov'
#
#  ENV.delete('COVERAGE')
#  SimpleCov.instance_exec do
#    start do
#      add_filter "/test/"
#      add_group('Missing'){|src| src.covered_percent < 100}
#      add_group('Covered'){|src| src.covered_percent == 100}
#      yield self if block_given?
#    end
#  end
# end

$LOAD_PATH << 'lib'
require 'conceptql'
ENV['MT_NO_PLUGINS'] = '1' # Work around stupid autoloading of plugins
require 'minitest/spec'
require 'minitest/autorun'

Minitest::Test.make_my_diffs_pretty!

module Minitest
  class Spec
    if ENV['TESTS_DIV_MOD']
      div, mod = ENV['TESTS_DIV_MOD'].split(' ', 2).map(&:to_i)
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

def check_sequel(query, source, name)
  file = Pathname.new('test') / 'fixtures' / source.to_s / "#{name}.txt"
  actual_sql = query.sql
  if !file.exist? || ENV['CONCEPTQL_OVERWRITE_TEST_RESULTS']
    file.dirname.mkpath
    file.write(actual_sql)
  end
  reggy = file.read
              .gsub('*', '\\*')
              .gsub(' +', ' \\\\+')
              .gsub('(', '\\(')
              .gsub(')', '\\)')
  _(actual_sql).must_match(Regexp.new(reggy))
end
