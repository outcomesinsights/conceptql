require_relative "rdbms/postgres"
require_relative "rdbms/impala"

module ConceptQL
  module Rdbms
    def self.generate(database_type, nodifier)
      case database_type.to_sym
      when :impala
        ConceptQL::Rdbms::Impala.new(nodifier)
      when :postgres
        ConceptQL::Rdbms::Postgres.new(nodifier)
      else
        raise "Unknown database_type -- '#{database_type}'"
      end
    end
  end
end
