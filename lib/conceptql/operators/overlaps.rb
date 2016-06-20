require_relative 'temporal_operator'

module ConceptQL
  module Operators
    class Overlaps < TemporalOperator
      register __FILE__, :omopv4

      desc <<-EOF
Compares all results on a person-by-person basis between the left hand results (LHR) and the right hand results (RHR).
Any result in the LHR with an end_date that occurs between the start_date and end_date of a result in the RHR is passed through.
All other results are discarded, including all results in the RHR.
L---Y---L
      R-----R
        L---N---L
      EOF
      def where_clause
        [Proc.new { l__start_date <= r__start_date}, Proc.new { r__start_date <= l__end_date }, Proc.new { l__end_date <= r__end_date }]
      end
    end
  end
end
