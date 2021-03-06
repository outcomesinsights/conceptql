if ENV['COVERAGE']
  require "coverage"
  require "seqelizer"
  require "simplecov"

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
require "conceptql"
ENV['MT_NO_PLUGINS'] = '1' # Work around stupid autoloading of plugins
require "minitest/spec"
require "minitest/autorun"
require "pry-rescue/minitest" if ENV["CONCEPTQL_PRY_RESCUE"]

Minitest::Test.make_my_diffs_pretty!

class Minitest::Spec
  if ENV['TESTS_DIV_MOD']
    div, mod = ENV['TESTS_DIV_MOD'].split(' ', 2).map(&:to_i)
    raise "invalid TESTS_DIV_MOD div: #{div}" unless div >= 2
    raise "invalid TESTS_DIV_MOD mod: #{mod} (div: #{div})" unless mod >= 0 && mod < div
    test_number = -1
    inc = proc{test_number+=1}

    singleton_class.prepend(Module.new do
      define_method(:it) do |*a, &block|
        if (i = inc.call) % div == mod
          super(*a, &block)
        end
      end
    end)
  end

  def sql_matches(sql, *matches)
    matches.each do |matchy|
      _(sql).must_match(matchy)
    end
  end

  def sql_doesnt_match(sql, *matches)
    matches.each do |matchy|
      _(sql).wont_match(matchy)
    end
  end
end
