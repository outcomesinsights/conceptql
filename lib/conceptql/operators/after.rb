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

      within_skip :after

      def right_stream(db)
        unless compare_all?
          right.evaluate(db).from_self.group_by(:person_id).select(:person_id, Sequel.function(:min, :end_date).as(:end_date)).as(:r)
        else
          right.evaluate(db).from_self.as(:r)
        end
      end

      def occurrences_column
        :end_date
      end

      def where_clause
        Sequel.expr { l[:start_date] > r[:end_date] }
      end

      def compare_all?
        !(options.keys & [:within, :at_least, :occurrences]).empty?
      end
    end
  end
end

