require_relative "generic"

module ConceptQL
  module Rdbms
    class Postgres < Generic
      def partition_fix(column, qualifier=nil)
        # Hack used because this code doesn't know if we are using PostgreSQL or Redshift
        return column unless ENV["CONCEPTQL_NO_CONSTANT_ORDER_BY"] == "true"

        person_id = qualifier ? Sequel.qualify(qualifier, :person_id).cast_string : :person_id
        person_id = Sequel.cast_string(person_id)
        column = Sequel.expr(column).cast_string
        column + '_' + person_id
      end

      def days_between(from_column, to_column)
        cast_date(to_column) - cast_date(from_column)
      end

      def create_options(scope, ds)
        {}
      end

      def drop_options
        {}
      end

      def post_create(db, table_name)
        # Do nothing
      end

      def preferred_formatter
        SqlFormatters::PgFormat
      end
    end
  end
end

