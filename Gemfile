# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in conceptql.gemspec
gemspec
gem 'pg'
gem 'sequelizer', github: 'outcomesinsights/sequelizer', branch: 'main'
gem 'sequel-duckdb', github: 'outcomesinsights/sequel-duckdb', branch: 'main'
gem 'overcommit', '~> 0.68'

group :duckdb, optional: true do
  gem 'duckdb'
end

group :hexspace, optional: true do
  gem 'sequel-hexspace', github: 'outcomesinsights/sequel-hexspace'
end
