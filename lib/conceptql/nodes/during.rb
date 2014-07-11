require_relative 'temporal_node'

module ConceptQL
  module Nodes
    class During < TemporalNode
      def where_clause
        if inclusive?
          Sequel.expr(Sequel.expr(Proc.new { r__start_date <= l__start_date}).&(Sequel.expr( Proc.new { l__start_date <= r__end_date })))
            .|(Sequel.expr(Proc.new { r__start_date <= l__end_date}).&(Sequel.expr( Proc.new { l__end_date <= r__end_date })))
        else
          [Proc.new { r__start_date <= l__start_date}, Proc.new { l__end_date <= r__end_date }]
        end
      end
    end
  end
end
