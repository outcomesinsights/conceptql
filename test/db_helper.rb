# frozen_string_literal: true

require 'English'
require_relative 'helper'
require_relative 'db'

require 'logger'
require 'pp'
require 'fileutils'

DB.extension :make_readyable

if DB.database_type.to_sym == :spark && ENV['CONCEPTQL_PARQUET_TEST_DIR'].present?
  DB.make_ready(search_path: Dir[ENV['CONCEPTQL_PARQUET_TEST_DIR']].map { |f| Pathname.new(f).glob('*.parquet') })
end

if DB.database_type.to_sym == :duckdb
  schemas = (ENV['SEQUELIZER_SEARCH_PATH'] || 'slim,gdm_vocabs,ohdsi_vocabs')
            .split(',')
            .map(&:strip)
            .reject(&:empty?)
            .map(&:to_sym)
  DB.make_ready(search_path: schemas)
end

CDB = ConceptQL::Database.new(DB, data_model: (ENV['CONCEPTQL_DATA_MODEL'] || ConceptQL::DEFAULT_DATA_MODEL).to_sym)
DB.extension :error_sql

PRINT_CONCEPTQL = ENV['CONCEPTQL_PRINT_SQL']

ENV['CONCEPTQL_IN_TEST_MODE'] = "I'm so sorry I did this"
