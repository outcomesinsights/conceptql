# frozen_string_literal: true

# `just spec` runs this through `just test-duckdb`, which sets up the DuckDB
# fixture on gdm_wide with the ohdsi_vocabs lexicon. test/db_helper.rb connects
# to it (DB) and makes the ConceptQL::Database (CDB).
require_relative "../../../test/db_helper"
require_relative "spec_build"

SpecBuild::Build.new(DB, CDB).run
