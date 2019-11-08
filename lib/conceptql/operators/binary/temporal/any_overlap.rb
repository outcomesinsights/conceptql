require_relative "base"

module ConceptQL
  module Operators
    module Binary
      module Temporal
        class AnyOverlap < Base
          register __FILE__

          desc 'If a result in the LHR overlaps in any way a result in the RHR, it is passed through.'

          def where_clause
            ((within_start <= l_start_date) & (l_start_date <= within_end)) | ((l_start_date <= within_start) & (within_start <= l_end_date))
          end
        end
      end
    end
  end
end
