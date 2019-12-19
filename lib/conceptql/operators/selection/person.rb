require_relative "base"

module ConceptQL
  module Operators
    module Selection
      class Person < Base
        include ConceptQL::Behaviors::Windowable
        include ConceptQL::Behaviors::Timeless

        register __FILE__

        desc 'Generates all person records, or, if fed a stream, fetches all person records for the people represented in the incoming result set.'
        domains :person
        validate_no_upstreams
        validate_no_arguments

        def domain
          :person
        end

        def table
          dm.nschema.people_cql
        end

        def where_clause(db)
          nil
        end
      end
    end
  end
end
