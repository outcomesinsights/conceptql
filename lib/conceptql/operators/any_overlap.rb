require_relative 'temporal_node'

module ConceptQL
  module Operators
    class AnyOverlap < TemporalNode
      desc 'If a result from the LHR overlaps in any way a result from the RHR it is passed along.'
      def where_clause
        l_partly_in_r = Sequel.expr { r__start_date <= l__start_date }.&(Sequel.expr { l__start_date <= r__end_date })
        r_partly_in_l = Sequel.expr { l__start_date <= r__start_date }.&(Sequel.expr { r__start_date <= l__end_date })
        l_partly_in_r.|(r_partly_in_l)
      end
    end
  end
end

