require_relative 'operator'

module ConceptQL
  module Nodes
    # Represents a node that will grab all person rows that match the given place_of_service_codes
    #
    # PlaceOfServiceCode parameters are passed in as a set of strings.  Each string represents
    # a single place_of_service_code.  The place_of_service_code string must match one of the values in the
    # concept_name column of the concept table.  If you misspell the place_of_service_code name
    # you won't get any matches
    class PlaceOfServiceCode < Operator
      desc 'Finds all visit_occurrences that match the Place of Service codes'
      argument :places_of_service, type: :codelist, vocab: 'Place of Service'
      types :visit_occurrence

      def query(db)
        db.from(:visit_occurrence___v)
          .join(:vocabulary__concept___vc, { vc__concept_id: :v__place_of_service_concept_id })
          .where(vc__concept_code: arguments.map(&:to_s))
          .where(vc__vocabulary_id: 14)
      end
    end
  end
end
