require_relative 'temporal_operator'

module ConceptQL
  module Operators
    class Contains < TemporalOperator
      register __FILE__

      desc <<-EOF
If a result in the left hand results (LHR) has a start_date on or before and an end_date on or after a result in the right hand results (RHR), it is passed through.
L--X-L
R-----R
L------Y--------L

      EOF

      def where_clause
        [Proc.new { l__start_date <= r__start_date}, Proc.new { r__end_date <= l__end_date }]
      end
    end
  end
end
