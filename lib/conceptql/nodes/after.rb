require_relative 'temporal_node'

module ConceptQL
  module Nodes
    class After < TemporalNode
      def where_clause
        Proc.new { l__start_date > r__end_date }
      end
    end
  end
end

