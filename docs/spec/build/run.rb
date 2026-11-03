# frozen_string_literal: true

# `just spec` runs this through `just test-duckdb`, which sets up the DuckDB
# fixture on gdm_wide with the ohdsi_vocabs lexicon. test/db_helper.rb connects
# to it (DB) and makes the ConceptQL::Database (CDB). `just spec-check` sets
# CONCEPTQL_SPEC_CHECK=1.
require_relative "../../../test/db_helper"
require_relative "spec_build"

puts "spec build: ruby #{RUBY_VERSION}, libduckdb #{DuckDB.library_version}"
SpecBuild::Build.new(DB, CDB, check: ENV["CONCEPTQL_SPEC_CHECK"] == "1").run
