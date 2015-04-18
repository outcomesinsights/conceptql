require_relative 'temporal_node'

module ConceptQL
  module Nodes
      desc <<-EOF
Compares all results on a person-by-person basis between the left hand results (LHR) and the right hand resuls (RHR).
For any result in the LHR whose end_date occurs before that most recent start_date of the RHR, that result is passed through.
All other results are discarded, including all results in the RHR.
      EOF
    class Before < TemporalNode
      def right_stream(db)
        right.evaluate(db).from_self.group_by(:person_id).select(:person_id, Sequel.function(:max, :start_date).as(:start_date)).as(:r)
      end

      def where_clause
        Proc.new { l__end_date < r__start_date }
      end
    end
  end
end
