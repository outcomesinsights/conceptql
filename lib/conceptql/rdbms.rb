require_relative "rdbms/postgres"
require_relative "rdbms/impala"

module ConceptQL
  module Rdbms
    def self.generate(database_type)
      case database_type.to_sym
      when :impala
        ConceptQL::Rdbms::Impala.new
      when :postgres
        ConceptQL::Rdbms::Postgres.new
      end
    end
  end
end
