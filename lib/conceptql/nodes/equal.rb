require_relative 'temporal_node'

module ConceptQL
  module Nodes
    class Equal < TemporalNode
      def where_clause
        { r__value_as_number: :l__value_as_number }
      end
    end
  end
end
