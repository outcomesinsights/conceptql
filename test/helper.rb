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
