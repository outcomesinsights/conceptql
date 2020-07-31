# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'conceptql/version'

Gem::Specification.new do |spec|
  spec.name          = 'conceptql'
  spec.version       = ConceptQL::VERSION
  spec.authors       = ['Ryan Duryea']
  spec.email         = ['aguynamedryan@gmail.com']
  spec.summary       = %q{Generate OMOP CDMv4-compatible queries from a ConceptQL file}
  spec.description   = %q{ConceptQL is a query language for specifying queries to be run OMOP CDMv4 structured data}
  spec.homepage      = 'https://github.com/outcomesinsights/conceptql'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'sequelizer', '~> 0.1'
  spec.add_dependency 'thor', '~> 0.19'
  spec.add_dependency 'sequel', '~> 5.34'
  spec.add_dependency 'activesupport', '~> 5'
  spec.add_dependency 'bigdecimal'
  spec.add_dependency 'json'
  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 10.3'
  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'byebug', '~> 11'
  spec.add_development_dependency 'simplecov', '~> 0.11'
  spec.add_development_dependency 'sqlite3', '~> 1.3'
end
