require_relative 'node'

module ConceptQL
  module Nodes
    class Gender < Node
      def types
        [:person]
      end

      def query(db)
        gender_concept_ids = values.map do |value|
          case value.to_s
          when /^m/i
            8507
          when /^f/i
            8532
          else
            value.to_i
          end
        end

        db.from(:person_with_dates)
          .where(gender_concept_id: gender_concept_ids)
      end
    end
  end
end
