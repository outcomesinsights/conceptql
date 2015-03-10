require_relative 'temporal_node'

module ConceptQL
  module Nodes
    class OverlappedBy < TemporalNode
      def where_clause
        if inclusive?
          [Proc.new { r__start_date <= l__start_date}, Proc.new { l__start_date <= r__end_date }]
        else
          [Proc.new { r__start_date <= l__start_date}, Proc.new { l__start_date <= r__end_date }, Proc.new { r__end_date <= l__end_date }]
        end
      end
    end
  end
end
