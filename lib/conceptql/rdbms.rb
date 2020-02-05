require_relative "rdbms/postgres"
require_relative "rdbms/sqlite"

module ConceptQL
  module Rdbms
    def self.get(database_type)
      case database_type.to_sym
      when :postgres
        ConceptQL::Rdbms::Postgres.new
      when :sqlite
        ConceptQL::Rdbms::Sqlite.new
      else
        raise "Unknown database_type -- '#{database_type}'"
      end
    end
  end
end
