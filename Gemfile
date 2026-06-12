# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in conceptql.gemspec
gemspec
gem 'pg'
gem 'sequelizer', github: 'outcomesinsights/sequelizer', branch: 'main'
gem 'sequel-duckdb', github: 'outcomesinsights/sequel-duckdb', branch: 'main'
gem 'overcommit', '~> 0.71'
# Transitive via rubocop. parallel 2.x requires ruby >= 3.4; pin to 1.x so the
# lockfile installs cleanly on the ruby 3.2 CI floor (DuckDB job + docker test
# image) instead of being downgraded at install time, which churns Gemfile.lock.
gem 'parallel', '< 2.0'

group :duckdb, optional: true do
  gem 'duckdb'
end

group :hexspace, optional: true do
  gem 'sequel-hexspace', github: 'outcomesinsights/sequel-hexspace'
end
