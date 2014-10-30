require_relative 'temporal_node'

module ConceptQL
  module Nodes
    class Contains < TemporalNode
      def where_clause
        [Proc.new { l__start_date <= r__start_date}, Proc.new { r__end_date <= l__end_date }]
      end
    end
  end
end
