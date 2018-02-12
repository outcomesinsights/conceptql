require_relative 'temporal_operator'

module ConceptQL
  module Operators
    class AnyOverlap < TemporalOperator
      register __FILE__

      desc 'If a result in the LHR overlaps in any way a result in the RHR, it is passed through.'
      def apply_where_clause(ds)
        clause = ((within_start <= l_start_date) & (l_start_date <= within_end)) | ((l_start_date <= within_start) & (within_start <= l_end_date))
        if options[:invert_match]
          ds.exclude(clause)
        else
          ds.where(clause)
        end
      end
    end
  end
end

