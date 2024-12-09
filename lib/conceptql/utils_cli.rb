require 'thor'
require 'sequelizer'
require 'psych'
require_relative 'utils'

module ConceptQL
  class UtilsCLI < Thor
    include Sequelizer

    desc 'dump_schema', 'Dumps out the schema for all tables in YAML format'
    def dump_schema
      puts ConceptQL::Utils.schema_dump(db)
    end
  end
end
