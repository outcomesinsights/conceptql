# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in conceptql.gemspec
gemspec
gem 'overcommit', '~> 0.73'
gem 'pg'
gem 'sequel-duckdb', github: 'outcomesinsights/sequel-duckdb', branch: 'main'
gem 'sequelizer', github: 'outcomesinsights/sequelizer', branch: 'main'

group :duckdb, optional: true do
  gem 'duckdb'
end

group :hexspace, optional: true do
  gem 'sequel-hexspace', github: 'outcomesinsights/sequel-hexspace', branch: 'main'
end
