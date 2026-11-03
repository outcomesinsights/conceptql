# frozen_string_literal: true

require_relative "operator"

module ConceptQL
  module Operators
    class Gender < Operator
      register __FILE__

      include ConceptQL::Behaviors::Windowable
      include ConceptQL::Behaviors::Timeless

      desc "Selects the patients with the given genders."
      argument :gender, type: :string, options: %w[Male Female Unknown],
                        meaning: "One or more genders. A value that starts with M selects the male patients, " \
                                 "and a value that starts with F selects the female patients. " \
                                 "Any other value, such as Unknown, selects the patients whose gender is " \
                                 "neither male nor female, including the patients with no gender. Case does not matter."
      returns "One person record for each patient whose gender is one of the given genders. " \
              "The start_date and the end_date of each record are the patient's birth date."
      example "All female patients", [ "gender", "Female" ]
      example "All male patients", [ "gender", "Male" ]
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
