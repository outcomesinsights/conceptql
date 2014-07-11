require_relative 'temporal_node'

module ConceptQL
  module Nodes
    class StartedBy < TemporalNode
      def where_clause
        [ { l__start_date: :r__start_date } ] + \
        if inclusive?
          [ Proc.new { l__end_date >= r__end_date } ]
        else
          [ Proc.new { l__end_date > r__end_date } ]
        end
      end
    end
  end
end
