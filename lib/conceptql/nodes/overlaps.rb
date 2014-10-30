require_relative 'temporal_node'

module ConceptQL
  module Nodes
    class Overlaps < TemporalNode
      def where_clause
        [Proc.new { l__start_date <= r__start_date}, Proc.new { r__start_date <= l__end_date }, Proc.new { l__end_date <= r__end_date }]
      end
    end
  end
end
