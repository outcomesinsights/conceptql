require_relative 'casting_node'

module ConceptQL
  module Operators
    class Death < CastingOperator
      desc 'Generates all death records, or, if fed a stream, fetches all death records for the people represented in the incoming result set.'
      types :death
      allows_one_upstream

      def my_type
        :death
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
