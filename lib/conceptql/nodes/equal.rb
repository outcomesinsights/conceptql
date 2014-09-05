require_relative 'temporal_node'

module ConceptQL
  module Nodes
    class Equal < TemporalNode
      def where_clause
        { r__value_as_numeric: :l__value_as_numeric }
      end
    end
  end
end
