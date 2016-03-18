require_relative 'operator'

module ConceptQL
  module Operators
    class ToSeerVisits < Operator
      register __FILE__, :omopv4
      validate_no_upstreams
      validate_no_arguments

      def domain
        :visit_occurrence
      end

      def query(db)
        query = options.map do |k, v|
          next if v.nil?
          db[:observation]
            .where(observation_source_value: k.to_s.upcase, value_as_string: v)
            .select(:visit_occurrence_id)
            .from_self
        end.compact.inject { |q, i| i.intersect(q) }
        db[:visit_occurrence].where(visit_occurrence_id: query)
      end
    end
  end
end


