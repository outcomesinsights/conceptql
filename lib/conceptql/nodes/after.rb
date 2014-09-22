require_relative 'temporal_node'

module ConceptQL
  module Nodes
    class After < TemporalNode
      def right_stream(db)
        right.evaluate(db).from_self.group_by(:person_id).select(:person_id, Sequel.function(:min, :end_date).as(:end_date)).as(:r)
      end

      def where_clause
        Proc.new { l__start_date > r__end_date }
      end
    end
  end
end

