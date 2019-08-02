require "conceptql/version"
require "conceptql/logger"
require "conceptql/paths"
require "conceptql/utils"
require "conceptql/operators/operator"
require "conceptql/behaviors/code_lister"
require "conceptql/behaviors/timeless"
require "conceptql/behaviors/unwindowable"
require "conceptql/behaviors/windowable"
require "conceptql/behaviors/utilizable"
require "conceptql/vocabularies/dynamic_vocabularies"
require "conceptql/query"
require "conceptql/null_query"
require "conceptql/database"
require "conceptql/data_model"
require "conceptql/columnizer"
require "conceptql/query"
require "conceptql/null_query"
require "conceptql/database"
require "conceptql/data_model"
require "conceptql/columnizer"

# byebug is only required during development
begin
  require "byebug"
rescue LoadError
  nil
end

Dir.glob(File.dirname(__FILE__) + "/../lib/conceptql/query_modifiers/**/*.rb").each do |file|
  require_relative file
end

module ConceptQL
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
Dir.new(File.dirname(__FILE__) + "/conceptql/operators").
  entries.
  each{|filename| require_relative "conceptql/operators/" + filename if filename =~ /\.rb\z/ && filename != File.basename(__FILE__)}
ConceptQL::Operators.operators.values.each(&:freeze)
