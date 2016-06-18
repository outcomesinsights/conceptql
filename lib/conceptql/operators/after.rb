require_relative 'temporal_operator'

module ConceptQL
  module Operators
    class After < TemporalOperator
      register __FILE__, :omopv4

      desc <<-EOF
Compares all results on a person-by-person basis between the left hand results (LHR) and the right hand results (RHR).
Any result in the LHR with a start_date that occurs after the earliest end_date in the RHR is passed through.
All other results are discarded, including all results in the RHR.
L-------N-------L
R-----R
   R-----R
        L-----Y----L
      EOF

      within_skip :after

      def right_stream(db)
        right.evaluate(db).from_self.group_by(:person_id).select(:person_id, Sequel.function(:min, :end_date).as(:end_date)).as(:r)
      end

      def occurrences_column
        :r__end_date
      end

      def where_clause
        Proc.new { l__start_date > r__end_date }
      end
    end
  end
end

