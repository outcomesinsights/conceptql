require_relative 'temporal_node'

module ConceptQL
  module Nodes
    class During < TemporalNode
      desc <<-EOF
Compares all results on a person-by-person basis between the left hand results (LHR) and the right hand resuls (RHR).
For any result in the LHR whose start_date and end_date occur within the start_date and end_date of a RHR row, that result is passed through.
All other results are discarded, including all results in the RHR.
      EOF

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
