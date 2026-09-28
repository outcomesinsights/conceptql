# frozen_string_literal: true

require 'open3'
require 'rbconfig'
require 'tmpdir'
require_relative '../../helper'

# sqlite3 is only a development dependency. A consumer with no LEXICON_URL
# used to get a Sequel.sqlite lexicon database built for every Database's
# lexicon, so without sqlite3 in its bundle the first query raised LoadError.
# The fallback is LexiconNoDB, which needs no gem.
#
# The subprocess has no LEXICON_URL and no Sequelizer configuration (it runs
# in an empty directory), and every require of sqlite3 raises LoadError, which
# is what a missing gem does.
describe 'using conceptql without sqlite3' do
  def hide_sqlite3
    <<~RUBY
      module Kernel
        alias_method :__conceptql_test_require, :require
        def require(name)
          if name.to_s.start_with?('sqlite3')
            raise LoadError, "cannot load such file -- \#{name} (hidden by load_without_sqlite3_test)"
          end

          __conceptql_test_require(name)
        end
        private :require
      end
    RUBY
  end

  def run_conceptql(script)
    lib = File.expand_path('../../../lib', __dir__)
    env = ENV.keys.grep(/\A(SEQUELIZER_|LEXICON_URL\z)/).to_h { |k| [k, nil] }
    Dir.mktmpdir do |dir|
      Open3.capture2e(env, RbConfig.ruby, '-I', lib, '-e', hide_sqlite3 + script, chdir: dir)
    end
  end

  it 'lists operators and builds SQL' do
    out, status = run_conceptql(<<~RUBY)
      require 'conceptql'
      puts "database_rb=\#{$LOADED_FEATURES.grep(%r{/conceptql/database\\.rb\\z}).first}"
      cdb = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
      operators = cdb.operators
      puts "operators=\#{operators.size} icd9cm=\#{operators.key?('icd9cm')} gender=\#{operators.key?('gender')}"
      puts "sql=\#{cdb.query(['icd9', '412']).sql.length.positive?}"
    RUBY

    _(status.success?).must_equal(true, out)
    _(out).must_include "database_rb=#{File.expand_path("../../../lib/conceptql/database.rb", __dir__)}"
    _(out).must_match(/operators=[1-9]\d* icd9cm=true gender=true/)
    _(out).must_include 'sql=true'
  end
end
