require_relative 'temporal_operator'

module ConceptQL
  module Operators
    class Before < TemporalOperator
      register __FILE__

      desc <<-EOF
Compares all records on a person-by-person basis between the left hand records (LHR) and the right hand records (RHR).
Any record in the LHR with an end_date that occurs before the most recent start_date of the RHR is passed through.
All other records are discarded, including all records in the RHR.
      EOF

      allows_at_least_option
      within_skip :before

      def right_stream_query(db)
        unless compare_all?
          right.evaluate(db).from_self.select_group(*matching_columns).select_append(Sequel.function(:max, :start_date).as(:start_date))
        else
          right.evaluate(db).from_self
        end
      end

      def where_clause
        before_date = r_start_date

        if at_least_option
          before_date = adjust_date(at_least_option, before_date, true)
        end

        before_clause = Sequel.expr(l_end_date <  before_date)

        if within_option
          before_clause &= l_end_date >= within_start
        end

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
