require_relative 'operator'

module ConceptQL
  module Operators
    class Gender < Operator
      register __FILE__, :omopv4

      desc 'Returns all person records that match the selected gender.'
      argument :gender, type: :string, options: ['Male', 'Female']
      types :person

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

        db.from(:person)
          .where(gender_concept_id: gender_concept_ids)
      end
    end
  end
end
