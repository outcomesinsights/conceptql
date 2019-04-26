require "conceptql/version"
require "conceptql/logger"
require "conceptql/paths"
require "conceptql/utils"
require "conceptql/behaviors/timeless"
require "conceptql/behaviors/unwindowable"
require "conceptql/behaviors/windowable"
require "conceptql/query"
require "conceptql/null_query"
require "conceptql/database"
require "conceptql/data_model"
require "conceptql/columnizer"

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
      'Select by Clinical Codes',
      'Select by Property',
      'Get Related Data',
      'Modify Data',
      'Combine Streams',
      'Filter by Comparing',
      'Filter Single Stream',
    ].map.with_index do |name, priority|
      { name: name, priority: priority }
    end
  end
end
