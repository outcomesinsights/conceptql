require_relative 'temporal_operator'

module ConceptQL
  module Operators
    class AnyOverlap < TemporalOperator
      register __FILE__

      desc "Compares records on a person-by-person basis and passes along left hand records with a date range that overlaps in any way with a right hand record's date_range."

      def where_clause
        ((within_start <= l_start_date) & (l_start_date <= within_end)) | ((l_start_date <= within_start) & (within_start <= l_end_date))
      end
    end
  end
end

