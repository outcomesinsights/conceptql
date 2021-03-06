require "pathname"
require "sequel"
%w(
  /../lib/conceptql/behaviors/*.rb
  /../lib/conceptql/data_model/views/*.rb
).each do |globby|
  Dir.glob(File.dirname(__FILE__) + globby).each do |file|
    require_relative file
  end
end
require 'active_support/core_ext/object/blank'
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
require "conceptql/query"
require "conceptql/null_query"
require "conceptql/database"
require "conceptql/data_model"

# byebug is only required during development
begin
  unless ENV["CONCEPTQL_PRY_RESCUE"]
    require "byebug"
    require "pry-byebug"
  end
rescue LoadError => e
  puts e.message
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
      operators: ConceptQL::Database.new(nil).query(["icd9", "412"]).send(:nodifier).to_metadata(opts)
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

Sequel::Database.extension(:retry)

# Require all operator subclasses eagerly
#
# First, require vocabulary operator.  It will establish operators for all
# vocabularies found in Lexicon.  Then other operators might override
# some of those dynamically generated operators
retries = 0
begin
  ConceptQL::Vocabularies::DynamicVocabularies.new.register_operators
rescue Sequel::DatabaseConnectionError => e
  if (retries += 1) <= 3
    timeout = retries * 5
    puts "Timeout (#{e.message.chomp}), retrying in #{timeout} second(s)..."
    sleep(timeout)
    retry
  else
    raise
  end
end
Pathname.glob(File.dirname(__FILE__) + "/conceptql/operators/**/*.rb")
  .entries
  .map { |e| e.to_s.gsub(File.dirname(__FILE__) + "/", '') }
  .each{ |filename| require_relative filename if filename =~ /\.rb\z/ && filename != File.basename(__FILE__)}
ConceptQL::Operators.operators.values.each(&:freeze)
