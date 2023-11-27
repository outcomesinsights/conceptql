require_relative "rdbms/postgres"
require_relative "rdbms/spark"

module ConceptQL
  module Rdbms
    def self.generate(database_type)
      case database_type.to_sym
      when :postgres
        ConceptQL::Rdbms::Postgres.new
      when :spark
        ConceptQL::Rdbms::Spark.new
      else
        raise "Unknown database_type -- '#{database_type}'"
      end
    end
  end
end
