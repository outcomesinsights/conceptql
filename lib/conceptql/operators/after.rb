require_relative 'temporal_operator'

module ConceptQL
  module Operators
    class After < TemporalOperator
      register __FILE__

      desc <<-EOF
Compares all results on a person-by-person basis between the left hand results (LHR) and the right hand results (RHR).
Any result in the LHR with a start_date that occurs after the earliest end_date in the RHR is passed through.
All other results are discarded, including all results in the RHR.
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
          right.evaluate(db).from_self.group_by(:person_id).select(:person_id, Sequel.function(:min, :end_date).as(:end_date))
        end
      end

      def apply_where_clause(ds)
        after_date = r_end_date

        if at_least_option
          after_date = adjust_date(at_least_option, after_date)
        end

        after_clause = l_start_date > after_date

        ds = ds.where(after_clause)

        if within_option
          within_clause = l_start_date <= within_end
          ds = ds.where(within_clause)
        end

        ds
      end

      def compare_all?
        !(options.keys & [:within]).empty?
      end

      def occurrences_column
        :end_date
      end

      def rhs_function
        compare_all? ? nil : :min
      end
    end
  end
end

