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
        (within_start <= r_start_date) & (r_end_date <= within_end)
      end

      def within_source_table
        Sequel[:l]
      end
    end
  end
end
