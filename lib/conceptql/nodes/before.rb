require_relative 'temporal_node'

module ConceptQL
  module Nodes
    class Before < TemporalNode
      def where_clause
        Proc.new { l__end_date < r__start_date }
      end
    end
  end
end
