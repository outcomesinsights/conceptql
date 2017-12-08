require "conceptql/version"
require "conceptql/logger"
require "conceptql/paths"
require "conceptql/utils"
require "conceptql/behaviors/windowable"
require "conceptql/query"
require "conceptql/null_query"
require "conceptql/database"
require "conceptql/data_model"
require_relative "conceptql/query_modifiers/gdm/pos_query_modifier"
require_relative "conceptql/query_modifiers/gdm/drug_query_modifier"
require_relative "conceptql/query_modifiers/gdm/provider_query_modifier"
require_relative "conceptql/query_modifiers/gdm/provenance_query_modifier"
require_relative "conceptql/query_modifiers/omopv4_plus/provider_query_modifier"
require_relative "conceptql/query_modifiers/omopv4_plus/pos_query_modifier"
require_relative "conceptql/query_modifiers/omopv4_plus/drug_query_modifier"
require_relative "conceptql/query_modifiers/omopv4_plus/provenance_query_modifier"

require 'securerandom'

module ConceptQL
  FORCE_TEMP_TABLES = ENV['CONCEPTQL_FORCE_TEMP_TABLES'] == "true"
  if FORCE_TEMP_TABLES
    SCRATCH_DATABASE = ENV['DOCKER_SCRATCH_DATABASE']
    unless SCRATCH_DATABASE && !SCRATCH_DATABASE.empty?
      raise ArgumentError, "You must set the DOCKER_SCRATCH_DATABASE environment variable to the name of the scratch database if using the CONCEPTQL_FORCE_TEMP_TABLES environment variable"
    end
  else
    SCRATCH_DATABASE = nil
  end

  i = 0
  mutex = Mutex.new
  CTE_NAME_NEXT = lambda{mutex.synchronize{i+=1}}
  def self.cte_name(name)
    name = Sequel.identifier("#{name}_#{$$}_#{CTE_NAME_NEXT.call}_#{SecureRandom.hex(16)}")

    if SCRATCH_DATABASE
      name = name.qualify(SCRATCH_DATABASE)
    end

    name
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
