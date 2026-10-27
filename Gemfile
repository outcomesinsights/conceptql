# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in conceptql.gemspec
gemspec
gem "pg"

# The OI gems come from their rubygems.org releases, as in every jigsaw project
# (jigsaw_builder-da6). Before 1.0 a minor release may break, so the 0.x gems
# are held to their minor line. To test an unreleased change, point the entry
# at a checkout with `path:` for that run, and do not commit it.
gem "sequel-duckdb", "~> 0.4.2"
gem "sequelizer", "~> 0.4.0"

# Optional, because the gem compiles against libduckdb, which only the DuckDB
# runs install (just test-duckdb, CI's DuckDB job). Gem 2.x only (Ryan,
# 2026-10-26); it builds against libduckdb 1.4 or newer.
group :duckdb, optional: true do
  gem "duckdb", "~> 2.0"
end

group :hexspace, optional: true do
  gem "sequel-hexspace", "~> 2.1"
end
