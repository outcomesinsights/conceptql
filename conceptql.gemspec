# frozen_string_literal: true

require 'English'
lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'conceptql/version'

Gem::Specification.new do |spec|
  spec.name          = 'conceptql'
  spec.version       = ConceptQL::VERSION
  spec.authors       = ['Ryan Duryea']
  spec.email         = ['aguynamedryan@gmail.com']
  spec.summary       = 'Generate OMOP CDMv4-compatible queries from a ConceptQL file'
  spec.description   = 'ConceptQL is a query language for specifying queries to be run OMOP CDMv4 structured data'
  spec.homepage      = 'https://github.com/outcomesinsights/conceptql'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'activesupport', '>= 6'
  spec.add_dependency 'bigdecimal'
  spec.add_dependency 'json'
  spec.add_dependency 'memo_wise', '~> 1.10'
  spec.add_dependency 'sequel', '~> 5.66'
  spec.add_dependency 'sequelizer', '~> 0.1.3'
  spec.add_dependency 'thor', '~> 1.0'
  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'climate_control'
  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'nokogiri', '~> 1.14'
  spec.add_development_dependency 'pry-byebug', '~> 3'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'simplecov', '~> 0.11'
  spec.add_development_dependency 'sqlite3', '~> 1.3'
  spec.add_development_dependency 'watir', '~> 7.3'
  spec.add_development_dependency 'webdrivers', '~> 5.2'
end
