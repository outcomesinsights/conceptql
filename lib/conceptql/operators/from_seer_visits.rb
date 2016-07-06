require_relative 'operator'

module ConceptQL
  module Operators
    class FromSeerVisits < Operator
      register __FILE__

      no_desc
      query_columns :observation
      validate_one_upstream

      def domain
        :observation
      end

      def query(db)
        visit_ids = stream.evaluate(db)
          .from_self
          .where(criterion_domain: 'visit_occurrence')
        query = db[:observation].where(visit_occurrence_id: visit_ids.select(:criterion_id))
        query = query.where(observation_source_value: arguments.map{|key| key.to_s.upcase}) unless arguments.empty?
        query
      end
    end
  end
end



