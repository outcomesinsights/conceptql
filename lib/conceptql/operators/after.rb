require_relative 'temporal_operator'

module ConceptQL
  module Operators
    class After < TemporalOperator
      register __FILE__

      desc <<-EOF
Compares all results on a person-by-person basis between the left hand results (LHR) and the right hand resuls (RHR).
For any result in the LHR whose start_date occurs after the earliest end_date of the RHR, that result is passed through.
All other results are discarded, including all results in the RHR.
L-------N-------L
R-----R
   R-----R
        L-----Y----L
      EOF
      def right_stream(db)
        right.evaluate(db).from_self.group_by(:person_id).select(:person_id, Sequel.function(:min, :end_date).as(:end_date)).as(:r)
      end

      def where_clause
        Proc.new { l__start_date > r__end_date }
      end
    end
  end
end

