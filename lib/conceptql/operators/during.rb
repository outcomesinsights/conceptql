require_relative 'temporal_operator'

module ConceptQL
  module Operators
    class During < TemporalOperator
      register __FILE__

      desc <<-EOF
Compares all results on a person-by-person basis between the left hand results (LHR) and the right hand results (RHR).
Any result in the LHR with a start_date and end_date that occur within the start_date and end_date of a result in the RHR is passed through.
All other results are discarded, including all results in the RHR.
      EOF

      def where_clause
        if inclusive?
          Sequel.expr{ ((r[:start_date] <= l[:start_date]) & (l[:start_date] <= r[:end_date])) | ((r[:start_date] <= l[:end_date]) & (l[:end_date] <= r[:end_date])) }
        else
          Sequel.expr{ (r[:start_date] <= l[:start_date]) & (l[:end_date] <= r[:end_date]) }
        end
      end
    end
  end
end
