# frozen_string_literal: true

require 'open3'
require 'rbconfig'
require_relative '../../helper'

# pry-byebug is only a development dependency, so a consumer that does not
# bundle it must still be able to `require 'conceptql'`. The subprocess makes
# every pry/byebug require raise LoadError, which is what a missing gem does,
# rather than maintaining a second bundle without it.
describe 'requiring conceptql without pry-byebug' do
  def hide_pry_byebug
    <<~RUBY
      module Kernel
        alias_method :__conceptql_test_require, :require
        def require(name)
          if name.to_s.start_with?('pry', 'byebug')
            raise LoadError, "cannot load such file -- \#{name} (hidden by load_without_pry_byebug_test)"
          end

          __conceptql_test_require(name)
        end
        private :require
      end
    RUBY
  end

  def load_conceptql(script)
    lib = File.expand_path('../../../lib', __dir__)
    Open3.capture2e(RbConfig.ruby, '-I', lib, '-e', hide_pry_byebug + script)
  end

  it 'loads' do
    out, status = load_conceptql(<<~RUBY)
      require 'conceptql'
      puts "loaded pry=\#{defined?(Pry).inspect} byebug=\#{defined?(Byebug).inspect}"
    RUBY

    _(status.success?).must_equal(true, out)
    _(out).must_include 'loaded pry=nil byebug=nil'
  end
end
