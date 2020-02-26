require_relative "base"

module ConceptQL
  module Operators
    # Filters the incoming stream of events to only those that have a
    # an associated visit_occurrence with the matching place_of_service
    #
    # Provenance related concepts are the ones found in the xxx_type_concept_id
    # field.
    #
    # If the event has NULL for the provenance-related field, they are filtered
    # out.
    #
    # Multiple provenances can be specified at once
    class PlaceOfServiceFilter < Base
      register __FILE__

      desc <<-EOF
Filters records to include only those that match one or more of the Medicare Place Of Service values.

Common values include 21 (inpatient hospital), 23 (emergency room), and 11 (office).
      EOF
      argument :places_of_service, type: :codelist, vocab: 'Place of Service'
      category "Filter Single Stream"
      basic_type :temporal
      allows_one_upstream
      validate_one_upstream
      validate_at_least_one_argument

      def query(db)
        upstream_query(db)
          .from_self(alias: :og)
          .semi_join(
            :place_of_service_join_view_v1,
            {
              Sequel[:psjv][:criterion_id] => Sequel[:og][:criterion_id],
              Sequel[:psjv][:criterion_table] => Sequel[:og][:criterion_table],
              Sequel[:psjv][:pos_concept_id] => place_of_service_concept_ids(db)
            },
            table_alias: :psjv
        )
      end

    private

      def place_of_service_concept_ids(db)
        db.from(:concepts)
          .where(vocabulary_id: "Place of Service")
          .where(concept_code: arguments.map(&:to_s))
          .select(:id)
      end
    end
  end
end
