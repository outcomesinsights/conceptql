# frozen_string_literal: true

require 'English'
require_relative 'helper'
require_relative 'db'

require 'logger'
require 'pp'
require 'fileutils'

puts 'Making CDB'
CDB = ConceptQL::Database.new(DB, data_model: (ENV['CONCEPTQL_DATA_MODEL'] || ConceptQL::DEFAULT_DATA_MODEL).to_sym)
DB.extension :error_sql

if DB.database_type.to_sym == :spark && ENV['CONCEPTQL_PARQUET_TEST_DIR'].present?
  DB.make_ready(search_path: Pathname.new(ENV['CONCEPTQL_PARQUET_TEST_DIR']).glob('*.parquet'))
end
puts 'Done'

PRINT_CONCEPTQL = ENV['CONCEPTQL_PRINT_SQL']

ENV['CONCEPTQL_IN_TEST_MODE'] = "I'm so sorry I did this"
