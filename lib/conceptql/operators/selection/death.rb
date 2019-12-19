require_relative "base"

module ConceptQL
  module Operators
    module Selection
      class Death < Base
        include ConceptQL::Behaviors::Windowable

        register __FILE__

        desc 'Generates all death records, or, if fed a stream, fetches all death records for the people represented in the incoming result set.'
        domains :death
        validate_no_upstreams
        validate_no_arguments

        def domain
          :death
        end

        def table
          dm.nschema.deaths_cql
        end

        def where_clause(db)
          nil
        end
      end
    end
  end
end
