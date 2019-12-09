require_relative "rdbms/postgres"

module ConceptQL
  module Rdbms
    def self.generate(database_type)
      case database_type.to_sym
      when :postgres
        ConceptQL::Rdbms::Postgres.new
      else
        raise "Unknown database_type -- '#{database_type}'"
      end
    end
  end
end
