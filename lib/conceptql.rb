require "pathname"
%w(
  /../lib/conceptql/query_modifiers/**/*.rb
  /../lib/conceptql/behaviors/*.rb
  /../lib/conceptql/data_model/views/*.rb
).each do |globby|
  Dir.glob(File.dirname(__FILE__) + globby).each do |file|
    require_relative file
  end
end
require "conceptql/version"
require "conceptql/logger"
require "conceptql/paths"
require "conceptql/utils"
require "conceptql/operators/base"
require "conceptql/query"
require "conceptql/faux_model"
require "conceptql/null_query"
require "conceptql/database"
require "conceptql/data_model"
require "conceptql/date_adjuster"
require "conceptql/columnizer"
require "conceptql/columns"
require "conceptql/query"
require "conceptql/null_query"
require "conceptql/database"
require "conceptql/data_model"
require "conceptql/columnizer"

# byebug is only required during development
begin
  require "byebug"
  require "pry"
rescue LoadError
  nil
end

require "conceptql/vocabularies/dynamic_vocabularies"

module ConceptQL
  DEFAULT_DATA_MODEL = :gdm

  def self.avoid_ctes?
    ENV['CONCEPTQL_AVOID_CTES'] == 'true'
  end

  def self.metadata(opts = {})
    {
      categories: categories,
      operators: ConceptQL::Nodifier.new.to_metadata(opts)
    }
  end

  def self.categories
    [
      "Select by Clinical Codes",
      "Select by Property",
      "Get Related Data",
      "Modify Data",
      "Combine Streams",
      "Filter by Comparing",
      "Filter Single Stream",
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
Pathname.glob(File.dirname(__FILE__) + "/conceptql/operators/**/*.rb")
  .entries
  .map { |e| e.to_s.gsub(File.dirname(__FILE__) + "/", '') }
  .tap { |e| p e }
  .each{ |filename| require_relative filename if filename =~ /\.rb\z/ && filename != File.basename(__FILE__)}
ConceptQL::Operators.operators.values.each(&:freeze)
