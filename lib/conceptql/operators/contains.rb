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
        Sequel.expr{ (l[:start_date] <= r[:start_date]) & (r[:end_date] <= l[:end_date]) }
      end
    end
  end
end
