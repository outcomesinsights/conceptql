require_relative 'temporal_operator'

module ConceptQL
  module Operators
    class StartedBy < TemporalOperator
      register __FILE__, :omopv4
      desc <<-EOF
If a result in the left hand results (LHR) has the same start_date and the same or a later end_date as a result in the right hand results (RHR), it is passed through.
L----Y----L
R-------R
L--N--L
      EOF
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
