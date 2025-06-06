# frozen_string_literal: true

require_relative 'temporal_operator'

module ConceptQL
  module Operators
    class After < TemporalOperator
      register __FILE__

      desc 'For each person, passes along left hand records with a start_date that occurs after the earliest end_date of a right hand record.'

      allows_at_least_option
      within_skip :after

      def right_stream_query(db)
        if compare_all?
          right.evaluate(db).from_self
        else
          right.evaluate(db).from_self.select_group(*matching_columns).select_append(Sequel.function(:min,
                                                                                                     :end_date).as(:end_date))
        end
      end

      def where_clause
        after_date = r_end_date

        after_date = adjust_date(at_least_option, after_date) if at_least_option

        clause = Sequel.expr(l_start_date > after_date)

        clause &= l_start_date <= within_end if within_option

        clause
      end

      def compare_all?
        !(options.keys & [:within]).empty?
      end

      def rhs_function
        compare_all? ? nil : :min
      end
    end
  end
end
