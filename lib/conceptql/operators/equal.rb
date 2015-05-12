require_relative 'temporal_node'

module ConceptQL
  module Operators
    class Equal < TemporalOperator
      desc 'If a LHR result has the same value_as_number as a RHR result, it is passed through'

      def where_clause
        { r__value_as_number: :l__value_as_number }
      end
    end
  end
end
