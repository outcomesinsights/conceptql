# This file is only used for TravisCI integration.

source "http://rubygems.org"

gemspec

gem "minitest", ">= 5.7.0"
gem "minitest-hooks"
gem "minitest-shared_description"

gem "sequelizer", github: "outcomesinsights/sequelizer", branch: "chisel"
gem "sequel_impala", github: "outcomesinsights/sequel_impala", branch: "chisel"
gem "thor"
gem "rake"

# MRI Adapter Dependencies
platforms :ruby do
  gem "sqlite3"
  gem "pg"
end

# JRuby Adapter Dependencies
platforms :jruby do
  gem "jdbc-sqlite3"
  gem "jdbc-postgres"
end
