# frozen_string_literal: true

require 'conceptql/version'
require 'conceptql/logger'
require 'conceptql/paths'
require 'conceptql/utils'
require 'conceptql/operators/operator'
require 'conceptql/behaviors/code_lister'
require 'conceptql/behaviors/timeless'
require 'conceptql/behaviors/unwindowable'
require 'conceptql/behaviors/windowable'
require 'conceptql/behaviors/utilizable'
require 'conceptql/vocabularies/dynamic_vocabularies'
require 'conceptql/visitors/metadata_extractor'
require 'conceptql/query'
require 'conceptql/null_query'
require 'conceptql/database'
require 'conceptql/data_model'
require 'conceptql/columnizer'

# byebug is only required during development
begin
  require 'pry-byebug'
rescue LoadError
  nil
end

Dir.glob("#{File.dirname(__FILE__)}/../lib/conceptql/query_modifiers/**/*.rb").sort.each do |file|
  require_relative file
end

module ConceptQL
  DEFAULT_DATA_MODEL = :gdm

  def self.avoid_ctes?
    ENV['CONCEPTQL_AVOID_CTES'] == 'true'
  end

  def self.metadata(cdb, opts = {})
    {
      categories: categories,
      operators: ConceptQL::Nodifier.new(cdb).to_metadata(opts)
    }
  end

  def self.categories
    [
      'Select by Clinical Codes',
      'Select by Property',
      'Get Related Data',
      'Modify Data',
      'Combine Streams',
      'Filter by Comparing',
      'Filter Single Stream'
    ].map.with_index do |name, priority|
      { name: name, priority: priority }
    end
  end
end

# Require all operator subclasses eagerly
#
# First, require vocabulary operator.  It will establish operators for all
# vocabularies found in Lexicon.  Then other operators might override
# some of those dynamically generated operators
ConceptQL::Vocabularies::DynamicVocabularies.new.register_operators
Dir.new("#{File.dirname(__FILE__)}/conceptql/operators")
   .entries
   .each do |filename|
  require_relative "conceptql/operators/#{filename}" if filename =~ /\.rb\z/ && filename != File.basename(__FILE__)
end
ConceptQL::Operators.operators.each_value(&:freeze)
