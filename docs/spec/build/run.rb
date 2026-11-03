# frozen_string_literal: true

# `just spec` runs this through `just test-duckdb`, which sets up the DuckDB
# fixture on gdm_wide with the ohdsi_vocabs lexicon. test/db_helper.rb connects
# to it (DB) and makes the ConceptQL::Database (CDB), which runs the examples
# and draws their diagrams. `just spec-check` sets CONCEPTQL_SPEC_CHECK=1.
#
# The fixture's lexicon publishes more operators than the spec documents, so
# a second database decides which operators get a reference section and which
# metadata it prints: gdm with no database and no custom vocabularies.
ENV.delete("CONCEPTQL_CUSTOM_VOCABULARIES")
ENV.delete("CONCEPTQL_CUSTOM_MULTIPLE_VOCABULARIES")
require_relative "../../../test/db_helper"
require_relative "spec_build"

puts "spec build: ruby #{RUBY_VERSION}, libduckdb #{DuckDB.library_version}"
reference = SpecBuild::Reference.new(ConceptQL.metadata(ConceptQL::Database.new(nil, data_model: :gdm)))
SpecBuild::Build.new(DB, CDB, reference: reference, check: ENV["CONCEPTQL_SPEC_CHECK"] == "1").run
