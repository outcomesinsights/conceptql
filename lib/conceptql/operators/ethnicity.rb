# frozen_string_literal: true

require_relative "operator"

module ConceptQL
  module Operators
    class Ethnicity < Operator
      register __FILE__

      desc "Selects the patients with the given ethnicities."
      domains :person
      category "Select by Property"
      basic_type :selection
      argument :ethnicity, type: :string, options: [ "Hispanic or Latino", "Not Hispanic or Latino" ],
                           meaning: "One or more ethnicities. A value that starts with Hispanic selects the " \
                                    "Hispanic or Latino patients, and a value that starts with Not Hispanic selects " \
                                    "the patients who are not Hispanic or Latino. A value that contains Unknown " \
                                    "selects the patients whose ethnicity concept ID is 0. Case does not matter, " \
                                    "and any other value selects no patients."
      returns "One person record for each patient whose ethnicity is one of the given ethnicities. " \
              "The start_date and the end_date of each record are the patient's birth date."
      example "All patients recorded as Hispanic", [ "ethnicity", "Hispanic" ]
      validate_no_upstreams
      validate_at_least_one_argument

      def table
        source_table
      end

      def source_table
        dm.person_table
      end

      def query(db)
        db.from(source_table)
          .where(ethnicity_concept_id: ethnicity_concept_ids)
      end

      def ethnicity_concept_ids
        arguments.map do |words|
          case words
          when /^Not Hispanic/i
            38_003_564
          when /^Hispanic/i
            38_003_563
          when /unknown/i
            [ 0, nil ]
          end
        end.flatten
      end
    end
  end
end
