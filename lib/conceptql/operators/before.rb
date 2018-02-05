require_relative 'temporal_operator'

module ConceptQL
  module Operators
    class Before < TemporalOperator
      register __FILE__

      desc <<-EOF
Compares all results on a person-by-person basis between the left hand results (LHR) and the right hand results (RHR).
Any result in the LHR with an end_date that occurs before the most recent start_date of the RHR is passed through.
All other results are discarded, including all results in the RHR.
      EOF

      allows_at_least_option
      within_skip :before

      def right_stream_query(db)
        unless compare_all?
          right.evaluate(db).from_self.group_by(:person_id).select(:person_id, Sequel.function(:max, :start_date).as(:start_date))
        else
          right.evaluate(db).from_self
        end
      end

      def apply_where_clause(ds)
        before_date = r_start_date

        if at_least_option
          before_date = adjust_date(at_least_option, before_date, true)
        end

        before_clause = l_end_date <  before_date

        ds = ds.where(before_clause)

        if within_option
          within_clause = l_end_date >= within_start
          ds = ds.where(within_clause)
        end

        ds
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
