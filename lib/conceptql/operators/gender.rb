require_relative 'operator'

module ConceptQL
  module Operators
    class Gender < Operator
      register __FILE__

      desc 'Returns all person records that match the selected gender.'
      argument :gender, type: :string, options: ['Male', 'Female']
      domains :person
      category "Select by Property"
      basic_type :selection
      validate_no_upstreams
      validate_at_least_one_argument

      def query(db)
        clauses = arguments.map do |arg|
          case arg.to_s
          when /^m/i
            Sequel.expr(gender_concept_id: male_ids(db))
          when /^f/i
            Sequel.expr(gender_concept_id: female_ids(db))
          else
            Sequel.expr(gender_concept_id: nil) | Sequel.~(gender_concept_id: male_ids(db) + female_ids(db))
          end
        end

        db.from(table)
          .where(clauses.inject(&:|))
      end

      def table
        dm.table_by_domain(:person)
      end

      def male_ids(db)
        dm.related_concept_ids(db, 8507)
      end

      def female_ids(db)
        dm.related_concept_ids(db, 8532)
      end
    end
  end
end
