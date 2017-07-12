require_relative 'temporal_operator'

module ConceptQL
  module Operators
    class AnyOverlap < TemporalOperator
      register __FILE__

      desc 'If a result in the LHR overlaps in any way a result in the RHR, it is passed through.'
      def where_clause
        Sequel.expr { ((r[:start_date] <= l[:start_date]) & (l[:start_date] <= r[:end_date])) | ((l[:start_date] <= r[:start_date]) & (r[:start_date] <= l[:end_date])) }
      end
    end
  end
end

