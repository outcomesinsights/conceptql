require "conceptql/version"
require "conceptql/logger"
require "conceptql/query"
require "conceptql/database"

module ConceptQL
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
