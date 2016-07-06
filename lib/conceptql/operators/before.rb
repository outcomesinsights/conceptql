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

      within_skip :before

      def right_stream(db)
        unless compare_all?
          right.evaluate(db).from_self.group_by(:person_id).select(:person_id, Sequel.function(:max, :start_date).as(:start_date)).as(:r)
        else
          right.evaluate(db).from_self.as(:r)
        end
      end

      def within_column
        :l__end_date
      end

      def where_clause
        Proc.new { l__end_date < r__start_date }
      end

      def compare_all?
        !(options.keys & [:within, :at_least, :occurrences]).empty?
      end
    end
  end
end
