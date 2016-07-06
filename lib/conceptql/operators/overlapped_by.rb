require_relative 'temporal_operator'

module ConceptQL
  module Operators
    class OverlappedBy < TemporalOperator
      register __FILE__

      desc <<-EOF
Compares all results on a person-by-person basis between the left hand results (LHR) and the right hand results (RHR).
Any result in the LHR with a start_date that occurs between the start_date and end_date of a result in the RHR is passed through.
All other results are discarded, including all results in the RHR.
L---N---L
      R-----R
        L---Y---L

      EOF
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
