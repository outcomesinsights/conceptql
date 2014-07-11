require_relative 'casting_node'

module ConceptQL
  module Nodes
    class Death < CastingNode
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
