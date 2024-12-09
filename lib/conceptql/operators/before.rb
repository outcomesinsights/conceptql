# frozen_string_literal: true

require_relative 'temporal_operator'

module ConceptQL
  module Operators
    class Before < TemporalOperator
      register __FILE__

      desc 'For each person, passes along left hand records with an end_date that occurs before the most recent start_date of a right hand record.'

      allows_at_least_option
      within_skip :before

      def right_stream_query(db)
        if compare_all?
          right.evaluate(db).from_self
        else
          right.evaluate(db).from_self.select_group(*matching_columns).select_append(Sequel.function(:max,
                                                                                                     :start_date).as(:start_date))
        end
      end

      def where_clause
        before_date = r_start_date

        before_date = adjust_date(at_least_option, before_date, true) if at_least_option

        before_clause = Sequel.expr(l_end_date < before_date)

        before_clause &= l_end_date >= within_start if within_option

        before_clause
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
