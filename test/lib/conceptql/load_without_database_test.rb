# frozen_string_literal: true

require 'open3'
require 'rbconfig'
require 'tmpdir'
require_relative '../../helper'

# Loading the library must not touch a database. It used to connect to
# whatever Sequelizer was configured for, to register an operator per
# vocabulary: with no database configured `require` crashed, and on DuckDB a
# second process could not even load conceptql while another held the file.
#
# The subprocess has no Sequelizer configuration at all: every SEQUELIZER_*
# variable is removed and it runs in an empty directory, so there is no .env
# or config/sequelizer.yml to find.
describe 'requiring conceptql with no database configured' do
  def load_conceptql(script)
    lib = File.expand_path('../../../lib', __dir__)
    env = ENV.keys.grep(/\ASEQUELIZER_/).to_h { |k| [k, nil] }
    Dir.mktmpdir do |dir|
      Open3.capture2e(env, RbConfig.ruby, '-I', lib, '-e', script, chdir: dir)
    end
  end

  it 'loads without opening a connection' do
    out, status = load_conceptql(<<~RUBY)
      require 'conceptql'
      puts "databases=\#{Sequel::DATABASES.size}"
    RUBY

    _(status.success?).must_equal(true, out)
    _(out).must_include 'databases=0'
  end
end
