require_relative 'node'

module ConceptQL
  module Nodes
    class FromSeerVisits < Node
      def type
        :observation
      end
      def query(db)
        visit_ids = stream.evaluate(db)
          .from_self
          .where(criterion_type: 'visit_occurrence')
        query = db[:observation].where(visit_occurrence_id: visit_ids)
        arguments.inject(query) do |q, key|
          q.where(observation_source_value: key.to_s.upcase)
        end
      end
    end
  end
end



