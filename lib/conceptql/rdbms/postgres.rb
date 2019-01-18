require_relative "generic"

module ConceptQL
  module Rdbms
    class Postgres < Generic
      def create_options(scope)
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

