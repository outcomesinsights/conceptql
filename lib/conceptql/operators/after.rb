require_relative 'temporal_operator'

module ConceptQL
  module Operators
    class After < TemporalOperator
      register __FILE__

      desc <<-EOF
Compares all records on a person-by-person basis between the left hand records (LHR) and the right hand records (RHR).
Any record in the LHR with a start_date that occurs after the earliest end_date in the RHR is passed through.
All other records are discarded, including all records in the RHR.
L-------N-------L
R-----R
   R-----R
        L-----Y----L
      EOF

      allows_at_least_option
      within_skip :after

      def right_stream_query(db)
        if compare_all?
          right.evaluate(db).from_self
        else
          right.evaluate(db).from_self.select_group(*matching_columns).select_append(Sequel.function(:min, :end_date).as(:end_date))
        end
      end

      def where_clause
        after_date = r_end_date

        if at_least_option
          after_date = adjust_date(at_least_option, after_date)
        end

        clause = Sequel.expr(l_start_date > after_date)

        if within_option
          clause = clause.&(l_start_date <= within_end)
        end

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

