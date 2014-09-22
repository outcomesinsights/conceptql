require_relative 'temporal_node'

module ConceptQL
  module Nodes
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
