# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in conceptql.gemspec
gemspec
gem 'pg'
gem 'sequelizer', github: 'outcomesinsights/sequelizer', branch: 'main'

group :duckdb, optional: true do
  gem 'duckdb'
  gem 'sequel-duckdb', github: 'outcomesinsights/sequel-duckdb', branch: 'main'
end

group :hexspace, optional: true do
  gem 'sequel-hexspace', github: 'outcomesinsights/sequel-hexspace'
end

group :development do
  gem 'overcommit', '~> 0.68'
end
