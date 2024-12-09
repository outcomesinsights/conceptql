# frozen_string_literal: true

require_relative 'temporal_operator'

module ConceptQL
  module Operators
    class Contains < TemporalOperator
      register __FILE__

      desc "For each person, passes along left hand records with a start_date and end_date containing a right hand record's start_date and end_date."

      def where_clause
        (within_start <= r_start_date) & (r_end_date <= within_end)
      end

      def within_source_table
        Sequel[:l]
      end
    end
  end
end
