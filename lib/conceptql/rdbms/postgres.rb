require_relative "generic"

module ConceptQL
  module Rdbms
    class Postgres < Generic
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
    end
  end
end

