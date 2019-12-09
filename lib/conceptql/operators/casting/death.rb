require_relative "base"

module ConceptQL
  module Operators
    module Casting
      class Death < Base
        include ConceptQL::Behaviors::Windowable

        register __FILE__

        desc 'Generates all death records, or, if fed a stream, fetches all death records for the people represented in the incoming result set.'
        domains :death
        allows_one_upstream

        def my_domain
          :death
        end

        def source_table
          dm.table_by_domain(:death)
        end

        def i_point_at
          [ :person ]
        end

        def these_point_at_me
          []
        end
      end
    end
  end
end
